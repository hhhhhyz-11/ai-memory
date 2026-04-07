# KingbaseES V9R2C14 PLSQL 报错处理

> 本文档介绍 KingbaseES V9R2C14 中 PL/SQL 存储过程和函数的报错处理方法。

---

## 一、PL/SQL 基础结构

### 1.1 块结构

```sql
-- 匿名块
DECLARE
    v_name VARCHAR2(50);
BEGIN
    v_name := 'Hello';
    DBMS_OUTPUT.PUT_LINE(v_name);
END;
/

-- 带异常处理的块
DECLARE
    v_id INTEGER;
BEGIN
    v_id := 1;
    SELECT name INTO v_name FROM users WHERE id = v_id;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No data found');
    WHEN TOO_MANY_ROWS THEN
        DBMS_OUTPUT.PUT_LINE('Too many rows');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/
```

### 1.2 存储过程创建

```sql
-- 创建存储过程
CREATE OR REPLACE PROCEDURE proc_name(
    p_id IN INTEGER,
    p_name IN VARCHAR2
)
AS
BEGIN
    INSERT INTO test_table(id, name) VALUES (p_id, p_name);
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END proc_name;
/

-- 调用存储过程
CALL proc_name(1, 'test');
```

---

## 二、常见 PLSQL 错误处理

### 2.1 未找到数据 (NO_DATA_FOUND)

**错误信息**：
```
ERROR: query returned no rows
```

**原因**：`SELECT INTO` 未找到匹配行

**处理方式**：

```sql
-- 方式一：使用异常处理
DECLARE
    v_name VARCHAR2(100);
BEGIN
    SELECT name INTO v_name FROM users WHERE id = 999;
    DBMS_OUTPUT.PUT_LINE('Name: ' || v_name);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('用户不存在');
END;
/

-- 方式二：使用函数返回默认值
DECLARE
    v_name VARCHAR2(100);
BEGIN
    SELECT COALESCE(name, 'N/A') INTO v_name FROM users WHERE id = 999;
    DBMS_OUTPUT.PUT_LINE('Name: ' || v_name);
END;
/

-- 方式三：使用 FOUND 属性（PostgreSQL/KingbaseES 兼容）
DECLARE
    v_name VARCHAR2(100);
BEGIN
    SELECT name INTO v_name FROM users WHERE id = 999;
    IF NOT FOUND THEN
        DBMS_OUTPUT.PUT_LINE('用户不存在');
    END IF;
END;
/
```

---

### 2.2 多行返回 (TOO_MANY_ROWS)

**错误信息**：
```
ERROR: more than one row returned by query subquery used in assignment context
```

**原因**：`SELECT INTO` 返回多行

**处理方式**：

```sql
-- 方式一：取第一条
BEGIN
    SELECT name INTO v_name FROM users WHERE status = 'active' LIMIT 1;

-- 方式二：使用聚合函数
BEGIN
    SELECT COUNT(*) INTO v_count FROM users WHERE status = 'active';

-- 方式三：使用数组接收
DECLARE
    v_names VARCHAR2(100)[];
BEGIN
    SELECT ARRAY_AGG(name) INTO v_names FROM users WHERE status = 'active';
END;
/
```

---

### 2.3 除零错误 (DIVISION_BY_ZERO)

**错误信息**：
```
ERROR: division by zero
```

**处理方式**：

```sql
-- 方式一：使用 NULLIF 避免除零
SELECT 
    CASE 
        WHEN divisor = 0 THEN NULL 
        ELSE dividend / divisor 
    END AS result
FROM table_name;

-- 方式二：使用 TRY 函数（如果支持）
SELECT 
    TRY(dividend / divisor) 
FROM table_name;

-- 方式三：异常处理
DECLARE
    v_result NUMBER;
BEGIN
    v_result := 10 / 0;
EXCEPTION
    WHEN DIVISION_BY_ZERO THEN
        v_result := 0;
        DBMS_OUTPUT.PUT_LINE('Division by zero caught');
END;
/
```

---

### 2.4 类型转换错误

**错误信息**：
```
ERROR: invalid input syntax for type integer: "abc"
```

**处理方式**：

```sql
-- 方式一：使用异常处理
DECLARE
    v_id INTEGER;
BEGIN
    v_id := TO_NUMBER('abc');
EXCEPTION
    WHEN OTHERS THEN
        v_id := 0;
        DBMS_OUTPUT.PUT_LINE('Invalid number');
END;
/

-- 方式二：使用正则验证
DECLARE
    v_id INTEGER;
    v_input VARCHAR2(50) := '123abc';
BEGIN
    IF v_input ~ '^[0-9]+$' THEN
        v_id := v_input::INTEGER;
    ELSE
        v_id := 0;
    END IF;
END;
/

-- 方式三：使用 TRY_CAST（如果支持）
SELECT TRY_CAST('123' AS INTEGER);
```

---

## 三、自定义异常

### 3.1 声明和使用自定义异常

```sql
DECLARE
    -- 定义自定义异常
    e_user_not_found EXCEPTION;
    e_insufficient_balance EXCEPTION;
    
    v_balance NUMBER := 100;
    v_amount NUMBER := 200;
BEGIN
    -- 触发自定义异常
    IF v_balance < v_amount THEN
        RAISE e_insufficient_balance;
    END IF;
    
EXCEPTION
    WHEN e_insufficient_balance THEN
        DBMS_OUTPUT.PUT_LINE('余额不足');
        RAISE_APPLICATION_ERROR(-20001, '余额不足，无法完成交易');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('未知错误: ' || SQLERRM);
        RAISE;
END;
/
```

### 3.2 RAISE_APPLICATION_ERROR

```sql
-- 语法
RAISE_APPLICATION_ERROR(error_number, message[, {TRUE | FALSE}]);

-- 示例
CREATE OR REPLACE PROCEDURE transfer(
    p_from_account IN INTEGER,
    p_to_account IN INTEGER,
    p_amount IN NUMBER
)
AS
    v_balance NUMBER;
BEGIN
    -- 检查余额
    SELECT balance INTO v_balance FROM accounts WHERE id = p_from_account;
    
    IF v_balance < p_amount THEN
        RAISE_APPLICATION_ERROR(-20001, '账户余额不足，当前余额: ' || v_balance);
    END IF;
    
    -- 执行转账
    UPDATE accounts SET balance = balance - p_amount WHERE id = p_from_account;
    UPDATE accounts SET balance = balance + p_amount WHERE id = p_to_account;
    COMMIT;
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END transfer;
/
```

---

## 四、异常处理函数

### 4.1 SQLERRM 和 SQLCODE

```sql
-- SQLERRM: 返回错误消息
-- SQLCODE: 返回错误代码

DECLARE
    v_err_msg VARCHAR2(500);
    v_err_code INTEGER;
BEGIN
    -- 可能出错的代码
    SELECT name INTO v_name FROM users WHERE id = 999;
    
EXCEPTION
    WHEN OTHERS THEN
        v_err_msg := SQLERRM;
        v_err_code := SQLCODE;
        DBMS_OUTPUT.PUT_LINE('Error Code: ' || v_err_code);
        DBMS_OUTPUT.PUT_LINE('Error Message: ' || v_err_msg);
        
        -- 记录到日志表
        INSERT INTO error_log(error_code, error_message, error_time)
        VALUES (v_err_code, v_err_msg, NOW());
        COMMIT;
END;
/
```

### 4.2 GET STACKED DIAGNOSTICS

```sql
-- 获取详细的异常诊断信息
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            v_db_name = PG_DATABASE,
            v_proc_name = PG_PROC_SCHEM || '.' || PG_PROC_NAME,
            v_line_no = PG_EXCEPTION_LINE;
        
        DBMS_OUTPUT.PUT_LINE('Database: ' || v_db_name);
        DBMS_OUTPUT.PUT_LINE('Procedure: ' || v_proc_name);
        DBMS_OUTPUT.PUT_LINE('Line: ' || v_line_no);
        
        RAISE;
```

---

## 五、函数返回错误

### 5.1 返回 NULL 表示错误

```sql
-- 返回 NULL 表示未找到
CREATE OR REPLACE FUNCTION get_user_name(p_id INTEGER)
RETURN VARCHAR2
AS
    v_name VARCHAR2(100);
BEGIN
    SELECT name INTO v_name FROM users WHERE id = p_id;
    RETURN v_name;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
END;
/

-- 调用时检查
DO $$
DECLARE
    v_name VARCHAR2(100);
BEGIN
    v_name := get_user_name(999);
    IF v_name IS NULL THEN
        RAISE NOTICE '用户不存在';
    ELSE
        RAISE NOTICE '用户名: %', v_name;
    END IF;
END $$;
```

### 5.2 使用 OUT 参数返回状态

```sql
CREATE OR REPLACE PROCEDURE find_user(
    p_id IN INTEGER,
    p_name OUT VARCHAR2,
    p_status OUT VARCHAR2
)
AS
BEGIN
    SELECT name, status INTO p_name, p_status 
    FROM users 
    WHERE id = p_id;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        p_name := NULL;
        p_status := 'NOT_FOUND';
END;
/

-- 调用
DECLARE
    v_name VARCHAR2(100);
    v_status VARCHAR2(20);
BEGIN
    find_user(999, v_name, v_status);
    IF v_status = 'NOT_FOUND' THEN
        RAISE NOTICE '用户不存在';
    ELSE
        RAISE NOTICE '用户: %', v_name;
    END IF;
END;
/
```

---

## 六、调试技巧

### 6.1 DBMS_OUTPUT

```sql
-- 启用输出
SET SERVEROUTPUT ON;

-- 打印消息
BEGIN
    DBMS_OUTPUT.PUT_LINE('调试信息: ' || TO_CHAR(SYSDATE));
END;
/

-- 在 PL/SQL 块中使用
DECLARE
    v_counter INTEGER := 0;
BEGIN
    FOR i IN 1..10 LOOP
        v_counter := v_counter + 1;
        DBMS_OUTPUT.PUT_LINE('Counter: ' || i);
    END LOOP;
END;
/
```

### 6.2 RAISE NOTICE

```sql
-- 使用 RAISE NOTICE 输出调试信息
DECLARE
    v_debug VARCHAR2(100) := 'debug value';
BEGIN
    RAISE NOTICE 'Debug: %', v_debug;
    RAISE NOTICE 'Current time: %', NOW();
END;
/

-- 在函数中调试
CREATE OR REPLACE FUNCTION test_func(p_id INTEGER)
RETURN INTEGER
AS
    v_result INTEGER;
BEGIN
    RAISE NOTICE 'Input parameter: %', p_id;
    
    SELECT COUNT(*) INTO v_result FROM users WHERE id = p_id;
    
    RAISE NOTICE 'Query result: %', v_result;
    
    RETURN v_result;
END;
```

---

## 七、错误日志表

### 7.1 创建错误日志表

```sql
-- 创建错误日志表
CREATE TABLE error_log (
    id SERIAL PRIMARY KEY,
    error_code VARCHAR2(20),
    error_message TEXT,
    error_detail TEXT,
    error_time TIMESTAMP DEFAULT NOW(),
    user_name VARCHAR2(100),
    client_addr INET,
    proc_name VARCHAR2(200)
);

-- 创建记录错误的存储过程
CREATE OR REPLACE PROCEDURE log_error(
    p_error_code VARCHAR2,
    p_error_message TEXT,
    p_error_detail TEXT DEFAULT NULL
)
AS
BEGIN
    INSERT INTO error_log(error_code, error_message, error_detail)
    VALUES (p_error_code, p_error_message, p_error_detail);
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        NULL;  -- 避免日志记录失败导致无限循环
END;
/
```

### 7.2 全局异常处理包装器

```sql
-- 创建通用的异常处理函数
CREATE OR REPLACE FUNCTION execute_with_log(
    p_sql TEXT,
    p_params JSON DEFAULT NULL
)
RETURNS VOID
AS $$
DECLARE
    v_result TEXT;
BEGIN
    EXECUTE p_sql;
    RAISE NOTICE '执行成功: %', p_sql;
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            v_result = RETURNED_SQLSTATE;
        
        -- 记录错误
        PERFORM log_error(
            v_result,
            SQLERRM,
            'SQL: ' || p_sql || ' | Params: ' || COALESCE(p_params::TEXT, 'N/A')
        );
        
        RAISE NOTICE '执行失败: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;
```

---

## 八、常见 PL/SQL 错误速查

| 错误信息 | 原因 | 解决方案 |
|---------|------|---------|
| `query returned no rows` | SELECT INTO 未找到数据 | 添加 EXCEPTION NO_DATA_FOUND |
| `more than one row` | SELECT INTO 返回多行 | 使用 LIMIT 或聚合函数 |
| `division by zero` | 除数为零 | 使用 NULLIF 或条件判断 |
| `invalid input syntax` | 类型转换失败 | 使用 TRY_CAST 或异常处理 |
| `relation does not exist` | 表或序列不存在 | 检查名称或添加 schema |
| `permission denied` | 权限不足 | GRANT 所需权限 |
| `null value` | NULL 值未处理 | 使用 COALESCE 或 NVL |
| `object not initialized` | 变量未初始化 | 确保在使用前赋值 |

---
