# MiniMax Skills 使用文档

> 来源：[xingkaixin/mimimax-skills](https://github.com/xingkaixin/mimimax-skills)（MIT 许可证）
> 安装位置：`~/.openclaw/workspace/skills/mimimax-skills/`

---

## 📦 已安装技能列表

| 技能 | 用途 | 触发关键词 |
|------|------|-----------|
| `frontend-dev` | 全栈前端开发 + UI设计 + AI媒体生成 | landing page、 marketing site、dashboard、图片/视频/音乐生成 |
| `fullstack-dev` | 全栈后端架构、前后端集成 | 全栈应用、REST API、实时功能、SSE/WebSocket |
| `android-native-dev` | Android 原生开发 | Android、Kotlin、Jetpack Compose、Material Design |
| `ios-application-dev` | iOS 应用开发 | iOS、SwiftUI、UIKit、SnapKit、Apple HIG |
| `shader-dev` | GLSL 着色器视觉效果 | shader、GLSL、光线追踪、粒子系统 |
| `gif-sticker-maker` | 照片转动画 GIF 贴纸 | GIF、贴纸、卡通、emoji、表情包 |
| `minimax-pdf` | PDF 生成/填写/重排 | PDF、报告、简历、表单、设计文档 |
| `pptx-generator` | PPT 生成/编辑/读取 | PPT、PPT X、演示文稿、幻灯片 |
| `minimax-xlsx` | Excel 创建/分析/编辑/验证 | Excel、xlsx、表格、财务模型、公式 |

---

## 🚀 使用方法

### 自动触发（推荐）

当我判断你的需求匹配某个技能时，会**自动读取**对应技能的 `SKILL.md` 和参考文档，然后按照技能的指导流程工作。

### 手动指定

也可以直接告诉我用哪个技能，例如：

```
帮我用 frontend-dev 技能做一个落地页
用 shader-dev 写一个 ray marching 效果
用 minimax-xlsx 创建一个财务模型
```

---

## 📁 技能目录结构

每个技能目录下包含：

```
skill-name/
├── SKILL.md           # 主技能说明（自动读取）
├── references/        # 参考文档（细分主题）
├── scripts/           # Python/JS 辅助脚本
├── templates/         # 模板文件
└── assets/            # 静态资源
```

### 技能详情

#### 🖥️ frontend-dev（98个文件）
全栈前端开发，涵盖：
- React / Next.js + Tailwind CSS
- Framer Motion / GSAP 电影级动画
- MiniMax API 生成图片、视频、音频、音乐、TTS
- AIDA 框架说服力文案
- 生成艺术（p5.js、Three.js、Canvas）
- 包含 85+ 字体文件（Canvas 绘图用）

#### ⚙️ fullstack-dev（9个文件）
- REST API 设计、认证流程（JWT/Session/OAuth）
- 实时功能（SSE、WebSocket）
- 数据库集成（SQL / NoSQL）
- 引导式工作流：需求收集 → 架构决策 → 实现
- 生产环境加固与发布清单

#### 🤖 android-native-dev（9个文件）
- Kotlin / Jetpack Compose
- Material Design 3
- 自适应布局、Gradle 配置
- 无障碍（WCAG）
- 性能优化与动效系统

#### 🍎 ios-application-dev（10个文件）
- UIKit / SwiftUI / SnapKit
- 触控目标、安全区域、导航模式
- Dynamic Type、深色模式、无障碍
- 集合视图，符合 Apple HIG 规范

#### 🎨 shader-dev（75个文件）
GLSL 着色器技术，包含 4 大模块：
- **fundamentals/**: 基础数学、硬件结构
- **reference/**: 36 个参考文档（光线追踪、SDF、流体模拟等）
- **techniques/**: 36 个技术教程
- 兼容 ShaderToy

#### 🎭 gif-sticker-maker（8个文件）
- 将照片转换为 4 张带字幕的动画 GIF 贴纸
- Funko Pop / Pop Mart 盲盒风格
- 基于 MiniMax 图片与视频生成 API

#### 📄 minimax-pdf（12个文件）
支持三种模式：
- **CREATE**: 从零生成 PDF（15种封面风格）
- **FILL**: 填写现有表单字段
- **REFORMAT**: 已有文档应用新设计
- 自动推导排版与配色

#### 📊 pptx-generator（6个文件）
- 从零创建 PPT（PptxGenJS）
- XML 工作流编辑现有 PPTX
- markitdown 提取文本
- 封面、目录、内容、分节页、总结页

#### 📈 minimax-xlsx（25个文件）
- 从零创建 xlsx（XML 模板方式）
- pandas 读取分析
- 零格式损失编辑现有文件
- 公式重算与验证
- 专业财务格式化
- 包含 OOXML 速查表

---

## 🛠️ 依赖说明

部分技能脚本依赖以下 Python 库：

```bash
pip install openai      # MiniMax API 调用
pip install python-pptx  # PPT 处理
pip install openpyxl     # Excel 处理
pip install pandas      # 数据分析
pip install requests    # HTTP 请求
pip install Pillow      # 图片处理
```

---

## 📝 备注

- Skills 源码仓库：https://github.com/xingkaixin/mimimax-skills
- 所有技能均为 MIT 许可证，可自由使用
- Skills 处于 Beta 阶段，内容可能随时更新
