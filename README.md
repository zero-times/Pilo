# 个人锻炼助手 Flutter 版（iOS + Android）

已实现核心能力：

- 动画计时按钮组件：`开始 -> 暂停 -> 完成 -> 重置`
- 完成反馈动画组件：打勾放大 + 粒子扩散 + 脉冲渐显提示
- DeepSeek API 接口联动：传入组件契约 + 用户资料 + 每日指标，返回训练条目 JSON
- 支持最近体重/血压序列输入，按每日变化动态生成训练、饮食和饮水建议
- 展示训练条目、饮食建议、饮水建议、风险提示

## 启动方式

```bash
cd fitness_flutter_app
flutter pub get
flutter run --dart-define=DEEPSEEK_API_KEY=你的Key
```

## 入参 JSON（发送给 DeepSeek）

- `profile`: 身高、体重、疾病情况、锻炼时长、器材
- `daily_metrics`: 当日体重、血压、日期
- `daily_metrics_history`: 最近多日体重与血压变化序列
- `component_contract`: 前端基础组件能力定义（计时按钮、完成反馈动画）

## 返回 JSON（要求 DeepSeek 输出）

```json
{
  "training_items": [
    {
      "title": "动作名称",
      "duration_minutes": 10,
      "intensity": "low|medium|high",
      "equipment": "器材",
      "instructions": "动作说明"
    }
  ],
  "components": [
    {
      "component": "timer_button|completion_feedback|training_card",
      "props": { "key": "value" }
    }
  ],
  "diet_advice": "饮食建议",
  "hydration_advice": "饮水建议",
  "hydration_target_ml": 2000,
  "warning": "风险提示"
}
```

## 说明

- 建议不要把密钥硬编码到仓库，统一使用 `--dart-define`。
- 当前为 MVP，可在下一步补充历史记录、趋势图、训练计划缓存和单元测试。
