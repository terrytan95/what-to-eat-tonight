# WhatToEatTonight

一款原生 iPhone App，用最少操作回答“今晚吃什么”。

## 当前功能

- 根据现有食材、可用时间和饮食需要推荐菜品，并显示缺少的食材和简要做法。
- 在家做或出去吃时一键给出明确选择，避开不喜欢和最近吃过的选项。
- 通过六位房间码在同一网络附近共同选择；数据端到端加密传输，不需要账号或服务器。

## 开发

需要 Xcode 26 或更高版本。打开 `WhatToEatTonight.xcodeproj`，选择 iPhone 模拟器运行。项目使用 SwiftUI、Observation 和 MultipeerConnectivity，不包含第三方依赖。

```sh
xcodebuild -project WhatToEatTonight.xcodeproj \
  -scheme WhatToEatTonight \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO
```

## App Store 准备

当前 bundle ID 为 `com.terrytan.WhatToEatTonight`，版本为 `0.1.0`，分类为 Food & Drink，并包含隐私清单。发布前仍需：

1. 确认 Apple Developer Team、最终 bundle ID 和最低系统版本。
2. 制作正式 App Icon、截图、支持网址和隐私政策网址。
3. 在真机验证局域网权限、两台设备同步、VoiceOver 和动态字体。
4. 扩充并审核菜品内容；当前内置数据只用于验证产品体验。
5. 在 App Store Connect 填写年龄分级、隐私问卷和审核备注。

## 未来付费边界

StoreKit 2 的加载、购买、交易验证和恢复购买流程已经接好，但在 App Store Connect 创建商品前不会展示价格。预留商品 ID：

- `com.terrytan.WhatToEatTonight.pro.monthly`
- `com.terrytan.WhatToEatTonight.lifetime`

适合付费的候选权益是扩展菜谱包、跨设备家庭菜单和跨网络多人房间；食材推荐、营养估算、基础快速决定和本地近距离房间保持免费。购买状态只以 StoreKit 验证交易为准，不自行保存“已付费”布尔值。
