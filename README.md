# WaterUp

WaterUp 的独立 iOS 工程，当前完成 F01 的工程初始化部分。

## 基线

- SwiftUI，最低支持 iOS 17。
- 三个一级入口：今日、历史、设置。
- 当前仅提供导航骨架和测试 Target；尚未接入 SwiftData、饮水记录、饮品、历史趋势或本地提醒。
- 后续实现顺序遵循 `../docs/WaterUp-功能拆分与实现计划-v1.0/`。

## 打开与构建

在 Xcode 中打开 `WaterUp.xcodeproj`，选择 `WaterUp` scheme 与任一 iOS 17+ 模拟器。

命令行构建示例：

```bash
xcodebuild -project WaterUp.xcodeproj -scheme WaterUp -sdk iphonesimulator build
```
