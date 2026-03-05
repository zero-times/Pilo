# AGENTS.md - AI 协作指南

> 本文件为 AI 代理（如 Claude Code）提供项目上下文，帮助理解代码库结构和开发规范。

## 项目概述

**名称**: fitness_flutter_app
**类型**: Flutter 跨平台健身训练应用
**语言**: Dart (SDK ^3.10.8)
**支持平台**: iOS, Android, Web, Windows, Linux, macOS
**界面语言**: 简体中文

### 核心功能

- AI 驱动的训练计划生成（DeepSeek API）
- 实时训练计时器与语音播报
- 训练历史与成就追踪
- 健康数据管理（体重、血压等）
- 数据导入/导出（JSON 备份）

---

## 项目结构

```
lib/
├── main.dart                    # 应用入口
└── src/
    ├── models/
    │   └── training_models.dart # 所有数据模型定义 (865行)
    ├── screens/
    │   ├── training_planner_page.dart    # 主页面 - 计划生成与设置
    │   ├── training_session_page.dart    # 训练执行页面
    │   ├── achievement_page.dart         # 成就与打卡统计
    │   ├── plan_history_page.dart        # 历史计划管理
    │   └── dashboard_view_data.dart      # 视图数据定义
    ├── services/
    │   ├── deepseek_service.dart         # AI API 服务
    │   ├── local_snapshot_store.dart     # 本地持久化存储
    │   ├── snapshot_portability_service.dart # 数据导入导出
    │   └── voice_broadcast_service.dart  # 语音播报服务
    ├── navigation/
    │   └── dashboard_tab_navigator.dart  # Tab 导航管理
    ├── theme/
    │   └── dashboard_tokens.dart         # 设计令牌与主题
    └── widgets/
        ├── animated_timer_button.dart    # 训练计时器按钮
        ├── completion_feedback.dart      # 完成动画反馈
        ├── dashboard_bottom_tab_bar.dart # 底部导航栏
        ├── dashboard_segmented_tab_selector.dart # 分段选择器
        ├── dashboard_tab_page_scaffold.dart # 页面脚手架
        └── risk_banner.dart              # 健康风险提示
```

---

## 架构模式

### 状态管理

- **无外部状态管理库**（不使用 Riverpod、GetX、Redux）
- 使用 Flutter 原生 `StatefulWidget` + `setState()` 模式
- 服务通过构造函数依赖注入（便于测试）
- 单一数据源：`LocalSnapshotStore`（本地文件持久化）

### 数据流

```
用户输入 (TrainingPlannerPage)
    ↓
DeepSeekService.generateTrainingPlan()
    ↓
TrainingPlan (内存)
    ↓
LocalSnapshotStore.updatePlan() (持久化)
    ↓
TrainingSessionPage (执行训练)
    ↓
LocalSnapshotStore.updateSessionState() (进度追踪)
    ↓
LocalSnapshotStore.appendOrUpdateCheckin() (历史记录)
```

### 服务职责

| 服务 | 职责 |
|------|------|
| `DeepSeekService` | AI 计划生成、API 通信、重试逻辑 |
| `LocalSnapshotStore` | 状态持久化、Schema 版本管理、成就计算 |
| `VoiceBroadcastService` | 中文语音播报 (zh-CN, rate 0.48) |
| `SnapshotPortabilityService` | JSON 备份导入导出 |

---

## 关键文件

### 入口点
- `lib/main.dart` - 应用启动入口

### 核心服务
- `lib/src/services/deepseek_service.dart` - AI API 调用与重试逻辑
- `lib/src/services/local_snapshot_store.dart` - 本地存储与状态管理

### 数据模型
- `lib/src/models/training_models.dart` - 所有模型定义（UserProfile、TrainingPlan、SessionState 等）

### 主要页面
- `lib/src/screens/training_planner_page.dart` - 主控制页面
- `lib/src/screens/training_session_page.dart` - 训练执行页面

### 配置
- `pubspec.yaml` - 依赖配置
- `analysis_options.yaml` - Lint 规则

---

## 主要依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| `http` | ^1.5.0 | HTTP 客户端 |
| `path_provider` | ^2.1.5 | 文件系统目录访问 |
| `file_picker` | ^10.3.2 | 文件选择（导入） |
| `share_plus` | ^12.0.1 | 平台原生分享 |
| `flutter_tts` | ^4.2.5 | 文字转语音 |

---

## 设计系统

### 主色调
```dart
accent = Color(0xFFF97316)        // 橙色主色
accentSoft = Color(0xFFFFEAD9)    // 浅橙色
success = Color(0xFF22C55E)       // 绿色（成功）
warning = Color(0xFFF59E0B)       // 琥珀色（警告）
info = Color(0xFF0A84FF)          // 蓝色（信息）
```

### 圆角规范
- 卡片圆角：`20.0`
- 按钮圆角：`12.0`

### 间距规范
- 屏幕边距：`16px`
- 元素间距：`8-16px`

---

## 代码规范

### 命名约定
- 文件名：`snake_case.dart`
- 类名：`PascalCase`
- 变量/方法：`camelCase`
- 私有成员：`_prefixedWithUnderscore`

### Widget 模式
- 优先使用 `StatelessWidget`
- 需要状态时使用 `StatefulWidget` + `setState()`
- 服务通过构造函数注入

### 错误处理
- 自定义异常类（如 `DeepSeekException`）
- 原子文件操作（临时文件 + 重命名）
- Schema 版本验证

---

## 测试

### 测试文件位置
```
test/
├── deepseek_service_test.dart        # API 服务测试
├── local_snapshot_store_test.dart    # 存储服务测试
├── training_session_page_test.dart   # 训练页面测试
├── app_snapshot_models_test.dart     # 模型序列化测试
├── widget_test.dart                  # Widget 渲染测试
├── plan_history_page_test.dart       # 历史页面测试
├── snapshot_portability_service_test.dart # 导入导出测试
├── animated_timer_button_test.dart   # 计时器按钮测试
└── achievement_page_test.dart        # 成就页面测试
```

### 运行测试
```bash
flutter test
```

### 测试模式
- 使用 `MockClient` 模拟 HTTP 请求
- 使用临时目录模拟文件系统
- Widget 测试使用 `pump()` 和 `pumpAndSettle()`

---

## 构建与运行

### 开发环境设置
```bash
flutter pub get
```

### 运行应用
```bash
flutter run                    # 默认设备
flutter run -d chrome          # Web
flutter run -d ios             # iOS 模拟器
flutter run -d android         # Android 模拟器
```

### 构建发布版本
```bash
flutter build apk              # Android APK
flutter build ios              # iOS
flutter build web              # Web
```

---

## API 集成

### DeepSeek API
- **主端点**: 通过 `ApiSettings` 配置
- **模型**: `gpt-5.3`
- **超时**: 45 秒
- **重试策略**: 3 次尝试，温度从 0.2 递减到 0.0
- **响应格式**: 纯 JSON（无 Markdown）

### 系统提示词
API 使用专业康复教练人设，生成训练计划时考虑用户健康状况和目标。

---

## 重要注意事项

### 数据持久化
- 所有状态保存在 `LocalSnapshotStore`
- Schema 版本：`currentSchemaVersion = 1`
- 文件格式：JSON
- 位置：应用文档目录

### 本地化
- 所有 UI 文本使用简体中文
- API 通信使用中文提示词
- 语音播报使用中文（zh-CN）

### 导航结构
- 四个主 Tab：首页、计划、统计、我的
- 使用 `Navigator.pushAndRemoveUntil()` 实现 Tab 隔离

---

## 常见任务

### 添加新页面
1. 在 `lib/src/screens/` 创建新文件
2. 使用 `DashboardTabPageScaffold` 作为脚手架
3. 在 `DashboardTabNavigator` 中注册路由

### 添加新 Widget
1. 在 `lib/src/widgets/` 创建新文件
2. 遵循现有命名和样式约定
3. 使用 `DashboardTokens` 中的设计令牌

### 修改数据模型
1. 在 `lib/src/models/training_models.dart` 中修改
2. 更新 `toJson()` 和 `fromJson()` 方法
3. 考虑 Schema 版本迁移

### 添加新服务
1. 在 `lib/src/services/` 创建新文件
2. 设计为可注入接口（便于测试）
3. 在需要的 Widget 构造函数中注入
