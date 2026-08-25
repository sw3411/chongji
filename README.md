# 宠迹（Chongji）— 宠物健康管理与生活记录 App

> 看见它的每一天：健康、饮食、时刻、消费，一本全记录。

「宠迹」是一款**本地优先**的宠物管理 App：记录猫狗的健康（体重/体型/疫苗/驱虫/就诊）、用 AI 生成每天每餐的喂食计划、用照片时间线记住值得纪念的时刻、把为它花的每一笔钱算清楚。不需要注册登录，数据保存在本机，随时可备份迁移。

支持 Android / iOS，手机竖屏优先，兼容深色模式，界面为简体中文。

## 功能列表

### 健康管理
- **宠物档案**：多宠物支持（首页头像横滑切换），物种/品种/生日/性别/绝育/头像，品种库内置 45+ 常见猫犬种及典型体重区间
- **健康记录**：体重、体型评分（BCS 1-9 图解选择器）、疫苗、体内/体外驱虫、就诊、用药、手术、症状，支持照片与备注
- **体重曲线**：fl_chart 折线图 + 近 30 天变化幅度
- **到期推算**：疫苗/驱虫按「最近一次 + 周期（可选 30 天/3 月/6 月/1 年，默认体内驱虫 3 月、体外 30 天、疫苗 1 年）」自动算下次时间
- **本地通知**：到期前 N 天（可设 1/3/7 天）+ 当天早上 9 点提醒；生日当天提醒；保存记录自动重排

### AI 饮食计划（核心）
- **饮食偏好**：主食类型（干粮/鲜食/混搭）、品牌、每天餐数、爱吃/不爱吃/过敏源
- **本地热量估算**：`RER = 70 × 体重^0.75 × 阶段系数`（幼年/成年/老年 × 绝育 × BCS 减肥），无 AI 时也有参考值
- **AI 生成喂食计划**：结合档案 + 偏好 + 估算，输出**日维度**（总热量/饮水建议）+ **顿维度**（每餐时间/食物/克数/热量），鲜食餐附食材清单与制作步骤，附整体建议与禁忌提醒（巧克力/葡萄/洋葱等）
- 计划按日保存（同日重新生成自动覆盖），饮食页查看今天/明天/历史

### AI 能力（预留 API，自行配置）
- **AI 对话助手**：流式打字机效果（自实现 SSE），支持 function calling 查本地数据（健康记录/体重趋势/消费汇总/饮食信息），模型不支持时自动降级
- **一句话记录**：「今天带豆豆打了狂犬疫苗花了200」→ 解析成健康记录/消费/时刻草稿 → 确认入库
- **健康周报**：汇总最近 7 天体重/体型/健康事件/消费/饮食，生成 Markdown 解读

### 时刻时间线
- 生日、游玩、美容、到家纪念日、纪念日、日常 6 类时刻，多照片（最多 9 张）
- 按月分组的照片卡片流，全屏大图查看（双指缩放/左右切换）

### 消费账本
- 8 个分类（主粮/零食/医疗/美容洗护/玩具/用品/保险/其他），可挂到具体宠物或"全体"
- 月度汇总大数字、分类占比饼图、年度月度趋势柱状图、月均消费
- 消费明细 CSV 导出（带 BOM，Excel 中文友好）

### 数据安全
- AI API Key 存入系统钥匙串/Keystore（flutter_secure_storage），数据库不落明文
- 单文件 JSON 备份（含图片 base64）、版本校验、覆盖/合并两种恢复、恢复前自动回滚备份
- 全部数据本机存储，无账号无云端

## 设计说明

视觉：**WhatsApp × Apple**。

- 配色为 WhatsApp 官方色板：主绿 `#008069`、亮绿 `#25D366`（发送/AI 唤起）、深色 `#0B141A`/`#202C33`、浅色气泡绿 `#DCF8C6`
- **字体层级严格区分大小与粗细**（`lib/app/theme.dart` 的 `AppTheme` 静态构造器）：

| 层级 | 规格 | 用途 |
|---|---|---|
| largeTitle | 34/w700 | 首页大标题、账本月汇总 |
| title | 22/w600 | 区块大标题 |
| cardTitle | 17/w600 | 列表行主标题（WhatsApp 联系人式加粗） |
| body | 16/w400 | 正文、表单 |
| subhead | 14/w400/灰 | 列表第二行（常规粗细+灰色，与主标题对比） |
| footnote/caption | 13/12/11/w400 | 辅助说明、时间戳 |
| bigNumber | 24-28/w700/等宽数字 | 体重、金额、倒计时 |
| label | 11.5/w600/+0.6字距 | 区块小标题 |

- 列表行为 WhatsApp 式：头像 + 加粗主标题 + 灰色副标题 + 右侧时间戳
- AI 对话为 WhatsApp 气泡（右侧浅绿 #DCF8C6 / 深色 #005C4B），生成中三点跳动

## 页面地图

| 页面 | 路由 |
|---|---|
| 引导 | `/onboarding` |
| 首页 | `/home` 宠物切换、今日概览、到期倒计时、最近时刻 |
| 健康 | `/health` 体重曲线、BCS、疫苗驱虫卡、按月分组记录 |
| 健康记录表单 | `/health/record/new`、`/health/record/:id/edit` |
| 时间线 | `/timeline`、`/moment/new`、`/moment/:id/edit` |
| 饮食 | `/diet`、`/diet/preferences` |
| 账本 | `/expenses`、`/expense/new`、`/expense/:id/edit` |
| 宠物 | `/pet/new`、`/pet/:id`、`/pet/:id/edit` |
| AI | `/ai/chat`、`/ai/quick-add`、`/ai/weekly` |
| 设置 | `/settings`、`/settings/ai`、`/settings/backup`、`/settings/about` |

底部导航：**首页 / 健康 / ＋（中央绿色圆钮：健康记录/时刻/消费/AI 一句话）/ 饮食 / 账本**。

## 技术栈

| 用途 | 选型 |
|---|---|
| 框架 | Flutter 3.32+ / Dart 3.8 |
| 状态管理 | flutter_riverpod |
| 路由 | go_router（StatefulShellRoute + 中央圆钮） |
| 数据库 | Drift + sqlite3_flutter_libs（7 张表，schema 迁移预留） |
| 图片 | image_picker（压缩 82%/1600px，存 App 私有目录） |
| 图表 | fl_chart（体重折线/消费饼图/趋势柱状） |
| AI | http（OpenAI 兼容 `/chat/completions`，含 SSE 流式与 function calling） |
| 通知 | flutter_local_notifications + timezone |
| 密钥 | flutter_secure_storage（encryptedSharedPreferences） |

## 项目架构

```
lib/
├── main.dart
├── app/          theme(字体层级) / router / app_shell / providers / app_settings / image_store
├── core/
│   ├── ai/       ai_client(阻塞+SSE流式+tools) / ai_config / ai_prompts / ai_service
│   ├── constants/ app_info / breeds(品种体重区间) / bcs(1-9图解)
│   ├── notifications/  到期+生日本地通知
│   └── utils/    formatters / money(int 分)
├── data/
│   ├── db/       tables(7表) / app_database(Row↔Domain 映射)
│   └── repositories/  pet / health_record / moment / expense / diet / settings / backup
├── domain/
│   ├── models/   pet / health_record / moment / expense / diet_profile / meal_plan / enums
│   └── services/ health_calculator / diet_calculator / statistics_service（纯函数 + now 注入）
├── features/     onboarding / home / health / timeline / diet / expenses / pets / settings / ai
└── shared/widgets/  common(空状态/徽标/指标卡/WhatsApp行) / photo_viewer
```

分层原则：**页面不写业务计算**——年龄/下次到期/体重趋势走 `HealthCalculator`，热量估算走 `DietCalculator`，统计口径走 `StatisticsService`；全部纯函数、`{DateTime? now}` 注入，可直接单测。金额一律 int 分存储。

## 环境要求与运行

- Flutter 3.32+（本机 SDK：`/Users/luckincoffee/Documents/flutter`，先 `export PATH="/Users/luckincoffee/Documents/flutter/bin:$PATH"`）
- Android：Android Studio + Android SDK；iOS：Xcode 15+（本机未装原生工具链，真机打包需先装齐）

```bash
cd chongji
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # 生成 Drift 代码（仅开发时）
flutter run
flutter build apk --release        # Android
cd ios && pod install && cd .. && flutter build ipa --release   # iOS（需签名）
```

## 测试

```bash
flutter test        # 56 个测试
flutter analyze     # 0 issues
```

覆盖：年龄/生活阶段/体重趋势/下次到期/生日推算、RER 与热量系数、饮水量/克数换算、消费统计口径（月度/分类占比/趋势/月均）、AI JSON 容错提取（裸/代码块/前后废话）、一句话解析、金额精度（int 分）、数据库往返（含同日计划覆盖、删除级联）、模型序列化、深浅色组件渲染。

## AI 功能配置

1. 进入「设置 → AI 助手设置」，开启启用开关
2. 填写（**接口已留好，你自己填**）：
   - **API 地址**：`https://api.openai.com/v1` / `https://api.deepseek.com/v1` / `https://open.bigmodel.cn/api/paas/v4`（GLM）/ 本地 Ollama `http://localhost:11434/v1`
   - **API Key**：仅存本机钥匙串
   - **模型名称**：`gpt-4o-mini` / `deepseek-chat` / `glm-4-flash` 等
3. 点「测试连接」验证后保存

隐私：AI 功能会把相关宠物数据发送到**你配置的** API 服务商；不配置则完全不发送任何数据。

## 权限说明

| 权限 | 时机 |
|---|---|
| 相机 | 仅在拍宠物头像/照片时 |
| 相册 | 仅在选择照片（时刻/记录/小票）时 |
| 通知 | 仅在设置中开启到期提醒时 |

## 已知限制与路线图

- AI 计划质量依赖所配模型；弱模型的 JSON 输出可能解析失败（已做多级容错）
- 通知在 App 被强制结束后由系统调度，Android 部分厂商需允许自启动
- 路线图（不阻塞）：云端同步与家庭共享、可穿戴设备数据、多语言、iPad 双栏
