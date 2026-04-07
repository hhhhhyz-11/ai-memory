# KingbaseES V9R2C14 表结构及 PL/SQL 报错处理（中/高级）

> 适用版本：KingbaseES V9R2C14
> 参考：https://docs.kingbase.com.cn/cn/KES-V9R2C14/application/application-develop-guide/reference/oracle/plsql/

---

## 一、表结构问题

### 1.1 表结构查看

```sql
-- 查看表结构
\d my_table

-- 详细列信息
SELECT
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'my_table'
ORDER BY ordinal_position;

-- 查看表注释
SELECT col_description('my_table'::regclass, attnum)
FROM sys_attribute
WHERE attrelid = 'my_table'::regclass AND attnum > 0;

-- 查看表的索引
SELECT indexname, indexdef
FROM sys_indexes
WHERE tablename = 'my_table';
```

### 1.2 表结构变更问题

#### 常见错误：字段存在但类型不兼容

```sql
-- 错误：无法直接修改字段类型（有数据时）
ALTER TABLE my_table ALTER COLUMN col1 TYPE VARCHAR2(100);

-- 解决方案 1：增加新列，迁移数据，删除旧列
ALTER TABLE my_table ADD COLUMN col1_new VARCHAR2(100);
UPDATE my_table SET col1_new = col1::VARCHAR;
ALTER TABLE my_table DROP COLUMN col1;
ALTER TABLE my_table RENAME COLUMN col1_new TO col1;

-- 解决方案 2：如果数据量小或可以接受
ALTER TABLE my_table ALTER COLUMN col1 TYPE VARCHAR2(100) USING col1::VARCHAR;
```

#### 常见错误：无法删除有依赖的列

```
ERROR: cannot drop column xxx because it is used by active relations
HINT: You can only drop the column if CASCADE is specified
```

```sql
-- 查看依赖
SELECT
    d.refobjid::regclass AS dependent_object,
    d.refobjsubid AS column_number,
    c.relkind,
    CASE c.relkind WHEN 'v' THEN 'view' WHEN 'm' THEN 'materialized view' END AS object_type
FROM sys_depend d
JOIN sys_class c ON d.refobjid = c.oid
WHERE d.classid = 'sys_attribute'::regclass
  AND d.objid = 'my_table'::regclass::oid || '.'::oid || 3;  -- 列号

-- 级联删除依赖对象
ALTER TABLE my_table DROP COLUMN col1 CASCADE;
```

### 1.3 临时表问题

```sql
-- 创建临时表（会话级）
CREATE TEMPORARY TABLE temp_data (
    id INT,
    name TEXT
);

-- 创建临时表（事务级）
CREATE TEMPORARY TABLE temp_data2 (
    id INT,
    name TEXT
) ON COMMIT DELETE ROWS;

-- 注意：临时表在不同会话中不可见
-- 检查临时表
SELECT * FROM sys_tables WHERE tablename LIKE 'temp%';
```

---

## 二、PL/SQL 编译错误

### 2.1 函数/存储过程编译失败

```sql
-- 查看编译错误
SELECT proname, prosrc, pronotnull, pronargs, proargtypes, prosqlobjver
FROM sys_proc
WHERE proname = 'my_function';

-- 更详细的信息
\d my_function

-- 查看特定函数的错误
SELECT line, col, message
FROM sys_backend_message_get()
WHERE session_id = sys_backend_pid()
ORDER BY line;
```

### 2.2 常见 PL/SQL 编译错误

| 错误信息 | 原因 | 解决方案 |
|---------|------|---------|
| `ERROR: function returned without OUT parameter` | 返回值未赋值 | 确保所有 OUT 参数都有值 |
| `ERROR: block RAISE exception without exception section` | 未处理异常 | 添加 EXCEPTION 处理块 |
| `ERROR: too many arguments` | 参数个数不匹配 | 检查函数调用参数 |
| `ERROR: record type does not support field assignment` | 记录类型赋值错误 | 使用 SELECT INTO 而非直接赋值 |
| `WARNING: function has conflicting names` | 函数名冲突 | 检查 schema 或使用 schema 前缀 |

### 2.3 重新编译无效对象

```sql
-- 查看所有无效对象
SELECT object_type, object_name, status
FROM sys_objects
WHERE status = 'INVALID';

-- 重新编译函数
ALTER FUNCTION my_function(param_type) COMPILE;

-- 重新编译所有无效函数
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT routine_name, routine_schema
             FROM information_schema.routines
             WHERE routine_type = 'FUNCTION'
               AND routine_schema NOT IN ('sys', 'information_schema')
    LOOP
        EXECUTE 'ALTER FUNCTION ' || r.routine_schema || '.' || r.routine_name || ' COMPILE';
    END LOOP;
END $$;

-- 或使用 sys_reload extension
SELECT sys_reload_extension('plsql');
```

---

## 三、PL/SQL 调试与错误处理

### 3.1 启用编译调试

```sql
-- 开启函数调试信息
ALTER FUNCTION my_function COMPILE DEBUG;

-- 查看函数的执行计划
EXPLAIN ANALYZE
SELECT my_function(param1, param2);
```

### 3.2 DBMS_OUTPUT 调试

```sql
-- 开启输出
SET SERVEROUTPUT ON

-- 在 PL/SQL 中使用
DECLARE
    v_result VARCHAR(100);
BEGIN
    DBMS_OUTPUT.PUT_LINE('开始执行...');
    DBMS_OUTPUT.PUT_LINE('参数值: ' || v_param);
    
    -- 业务逻辑
    v_result := '完成';
    
    DBMS_OUTPUT.PUT_LINE('结果: ' || v_result);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('错误: ' || SQLERRM);
        RAISE;
END;
/

-- 查看输出
SHOW SERVEROUTPUT;
```

### 3.3 RAISE 异常处理

```sql
-- 自定义异常
DECLARE
    e_not_found EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_not_found, -20001);
    v_recordcount INT;
BEGIN
    SELECT COUNT(*) INTO v_recordcount FROM my_table WHERE id = param_id;
    
    IF v_recordcount = 0 THEN
        RAISE e_not_found;
    END IF;
    
    -- 业务逻辑
    
EXCEPTION
    WHEN e_not_found THEN
        DBMS_OUTPUT.PUT_LINE('记录不存在');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('未知错误: ' || SQLERRM);
        RAISE;
END;
/
```

### 3.4 GET STACKED DIAGNOSTICS

```sql
-- 获取详细错误信息
DECLARE
    v_state VARCHAR(5);
    v_message TEXT;
    v_detail TEXT;
BEGIN
    -- 可能出错的语句
    NULL;
    
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            v_state = RETURNED_SQLSTATE,
            v_message = MESSAGE_TEXT,
            v_detail = PG_EXCEPTION_DETAIL;
        
        RAISE NOTICE 'State: %, Message: %, Detail: %', v_state, v_message, v_detail;
        
        RAISE;
END;
/
```

---

## 四、游标问题

### 4.1 游标未找到

```
ERROR: cursor "xxx" does not exist

原因：游标在异常处理中未关闭，或游标作用域问题
```

```sql
-- 正确使用游标的完整示例
DECLARE
    v_cursor REFCURSOR;
    v_id INT;
    v_name VARCHAR(100);
BEGIN
    OPEN v_cursor FOR SELECT id, name FROM my_table WHERE status = 1;
    
    LOOP
        FETCH v_cursor INTO v_id, v_name;
        EXIT WHEN NOT FOUND;
        
        -- 处理每一行
        DBMS_OUTPUT.PUT_LINE('ID: ' || v_id || ', Name: ' || v_name);
    END LOOP;
    
    CLOSE v_cursor;
    
EXCEPTION
    WHEN OTHERS THEN
        IF v_cursor%ISOPEN THEN
            CLOSE v_cursor;
        END IF;
        RAISE;
END;
/
```

### 4.2 游标变量问题

```sql
-- 使用弱类型游标
DECLARE
    v_cursor SYS_REFCURSOR;
BEGIN
    OPEN v_cursor FOR 'SELECT * FROM my_table WHERE id = :1' USING param_value;
    -- 处理...
    CLOSE v_cursor;
END;
/
```

---

## 五、触发器问题

### 5.1 触发器编译错误

```sql
-- 查看触发器定义
SELECT trigger_name, action_statement, trigger_type
FROM information_schema.triggers
WHERE event_object_table = 'my_table';

-- 触发器常见错误
-- 1. 递归触发器
-- 2. 触发器中修改正在触发的表
-- 3. BEFORE INSERT ON my_table 无法看到新行

-- 禁用触发器（数据迁移时）
ALTER TABLE my_table DISABLE TRIGGER ALL;

-- 启用触发器
ALTER TABLE my_table ENABLE TRIGGER ALL;

-- 禁用单个触发器
ALTER TABLE my_table DISABLE TRIGGER my_trigger;
```

### 5.2 触发器递归问题

```
ERROR: stack depth limit exceeded

原因：触发器相互调用导致无限递归
```

```sql
-- 检查触发器依赖
SELECT
    t.tgname AS trigger_name,
    c.relname AS table_name
FROM sys_trigger t
JOIN sys_class c ON t.tgrelid = c.oid
WHERE t.tgname IN (
    SELECT DISTINCT trigger_name
    FROM information_schema.triggers
);

-- 解决方案：使用条件判断避免递归
CREATE OR REPLACE TRIGGER my_trigger
AFTER INSERT ON my_table
FOR EACH ROW
DECLARE
    v_in_trigger BOOLEAN := FALSE;
BEGIN
    -- 检查是否在触发器上下文中
    IF NOT v_in_trigger THEN
        v_in_trigger := TRUE;
        -- 执行操作
        UPDATE my_table SET update_time = NOW() WHERE id = :NEW.id;
    END IF;
END;
```

---

## 六、存储过程执行问题

### 6.1 OUT 参数问题

```sql
-- 正确调用带 OUT 参数的存储过程
DECLARE
    v_result INT;
    v_output VARCHAR(100);
BEGIN
    my_procedure(
        param1 => 'value1',
        param2 => 'value2',
        result_count => v_result,      -- OUT 参数
        result_message => v_output     -- OUT 参数
    );
    
    DBMS_OUTPUT.PUT_LINE('Count: ' || v_result);
    DBMS_OUTPUT.PUT_LINE('Message: ' || v_output);
END;
/

-- 匿名块调用
CALL my_procedure('value1', 'value2', NULL, NULL);  -- 需要提供 OUT 参数占位
```

### 6.2 函数调用问题

```sql
-- 正确调用返回集合的函数
-- 首先创建返回集合的函数
CREATE OR REPLACE FUNCTION get_employees(p_dept_id INT)
RETURNS SETOF employees AS $$
BEGIN
    RETURN QUERY SELECT * FROM employees WHERE department_id = p_dept_id;
END;
$$ LANGUAGE plpgsql;

-- 调用
SELECT * FROM get_employees(10);

-- 在 PL/SQL 中调用
DECLARE
    r employees%ROWTYPE;
BEGIN
    FOR r IN SELECT * FROM get_employees(10) LOOP
        DBMS_OUTPUT.PUT_LINE(r.employee_name);
    END LOOP;
END;
/
```

---

## 七、性能问题

### 7.1 执行计划分析

```sql
-- 查看执行计划
EXPLAIN ANALYZE
SELECT * FROM my_table WHERE create_time > '2026-01-01';

-- 查看详细执行信息
EXPLAIN (ANALYZE, BUFFERS, COSTS, VERBOSE)
SELECT * FROM my_table WHERE id = 100;

-- 使用 auto_explain 查看慢查询
-- 参见 14-基础运维工具.md
```

### 7.2 PL/SQL 性能优化

```sql
-- 使用数组批量处理代替逐行处理
-- 不推荐：
FOR r IN (SELECT * FROM big_table) LOOP
    INSERT INTO dest_table VALUES (r.id, r.name);
END LOOP;

-- 推荐：使用批量 INSERT
INSERT INTO dest_table (id, name)
SELECT id, name FROM big_table;

-- 或使用 BULK COLLECT
DECLARE
    TYPE t_table IS TABLE OF big_table%ROWTYPE;
    v_rows t_table;
    CURSOR c_data IS SELECT * FROM big_table;
BEGIN
    OPEN c_data;
    LOOP
        FETCH c_data BULK COLLECT INTO v_rows LIMIT 10000;
        FORALL i IN 1..v_rows.COUNT
            INSERT INTO dest_table VALUES v_rows(i);
        EXIT WHEN v_rows.COUNT < 10000;
    END LOOP;
    CLOSE c_data;
    COMMIT;
END;
/
```

### 7.3 锁等待问题

```sql
-- 查看当前锁
SELECT
    l.locktype,
    l.relation::regclass,
    l.mode,
    l.granted,
    l.pid,
    a.usename,
    a.query
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE NOT l.granted;

-- 查看等待中的查询
SELECT
    pid,
    usename,
    query,
    state,
    wait_event_type,
    wait_event,
    query_start
FROM sys_stat_activity
WHERE wait_event_type IS NOT NULL
  AND state != 'idle';

-- 杀掉阻塞进程
SELECT pg_terminate_backend(pid)
FROM sys_stat_activity
WHERE pid = <阻塞进程的PID>;
```

---

## 八、常用诊断 SQL

```sql
-- 1. 查看长时间运行的查询
SELECT pid, now() - query_start AS duration, state, query
FROM sys_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC;

-- 2. 查看等待事件
SELECT wait_event_type, wait_event, COUNT(*)
FROM sys_stat_activity
GROUP BY wait_event_type, wait_event
ORDER BY COUNT(*) DESC;

-- 3. 查看大表
SELECT relname, pg_size_pretty(pg_total_relation_size(relid))
FROM sys_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 10;

-- 4. 查看索引使用情况
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM sys_stat_user_indexes
ORDER BY idx_scan DESC;

-- 5. 查看表膨胀
SELECT
    schemaname || '.' || tablename AS table_name,
    pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) AS bloat
FROM sys_stat_user_tables
ORDER BY pg_total_relation_size(relid) - pg_relation_size(relid) DESC
LIMIT 10;
```
