# 宠迹（Chongji）— 宠物健康管理与生活记录 App

> 看见它的每一天：健康、饮食、时刻、消费，一本全记录。

「宠迹」是一款**本地优先**的宠物管理 App：记录猫狗的健康（体重/体型/疫苗/驱虫/就诊）、用 AI 生成每天每餐的喂食计划、用照片时间线记住值得纪念的时刻、把为它花的每一笔钱算清楚。不需要注册登录，数据保存在本机，随时可备份迁移；也能通过「云空间」在家人间加密共享。

支持 Android / iOS，手机竖屏优先，深浅色双主题，界面为简体中文。

## 功能列表

### 首页 · 照片英雄区
- **顶部照片轮播**：当前宠物的照片铺满首屏，支持在设置中添加专属轮播图（每宠上限 30 张），8 秒自动切换、随时手动滑动；异比例照片自动「毛玻璃信封盒」过渡（模糊底 + 原图居中渐显，边缘自然融霜）
- **核心信息坐进照片**：当前体重（Manrope 大数字）、体型 BCS、下次到期事项白字直排照片底部，整体 10% 压暗保证可读
- **家人式问候**：「下午好呀，今天是8月27日 星期四，我们的九月 2岁3个月啦」
- **信息流**：AI 近期关注（综合判断，可一键更新）→ 到期提醒 → 最近时刻

### 健康管理
- **宠物档案**：多宠物支持（顶部头像一键切换），物种/品种/生日/性别/绝育/头像，品种库内置 45+ 常见猫犬种及典型体重区间
- **健康记录**：体重、体型评分（BCS 1-9 图解选择器）、疫苗、体内/体外驱虫、就诊、用药、手术、症状，支持照片与备注
- **体重曲线**：折线图 + 近 3 个月窗口，触控查值、涨跌着色（红涨绿跌）
- **到期推算**：疫苗/驱虫按「最近一次 + 周期（30 天/3 月/6 月/1 年）」自动算下次时间；体重/体型满 7 天提醒复测
- **本地通知**：
  - 到期前 N 天（可设 1/3/7 天）+ 当天早上 9 点提醒，生日/到家纪念日当天祝贺
  - **每日提醒摘要**：每天定时（时间可调）推送一条「宠迹 · 今日提醒」，汇总全部宠物 7 天内的到期事项；预排未来 7 天，几天不开 App 也照常推送

### AI 饮食计划（核心）
- **饮食偏好**：主食类型（干粮/鲜食/混搭）、品牌、每天餐数、爱吃/不爱吃/过敏源
- **本地热量估算**：`RER = 70 × 体重^0.75 × 阶段系数`（幼年/成年/老年 × 绝育 × BCS 减肥），无 AI 时也有参考值
- **AI 生成喂食计划**：结合档案 + 偏好 + 估算，输出**日维度**（总热量/饮水建议）+ **顿维度**（每餐时间/食物/克数/热量），鲜食餐附食材清单与制作步骤
- 计划按日保存（同日重新生成自动覆盖），饮食页查看今天/明天/历史

### AI 能力（预留 API，自行配置）
- **AI 对话助手**：流式打字机效果（自实现 SSE），思考过程自动折叠；支持 function calling 主动查询本地数据（健康记录/体重趋势/消费汇总/饮食信息），模型不支持时自动降级
- **一句话记录**：「今天带豆豆打了狂犬疫苗花了200」→ 解析成健康记录/消费/时刻草稿 → 确认入库
- **健康周报**：汇总最近 7 天数据生成 Markdown 解读，历史保存（每宠 30 份）、默认显示最近一次

### 时刻时间线
- 生日、游玩、美容、到家纪念日、纪念日、日常 6 类时刻，多照片（最多 9 张）
- 按月分组的照片卡片流，全屏大图查看（双指缩放/左右切换），Hero 共享元素转场
- 拍照自动读取 EXIF 填充日期与 GPS 地名

### 消费账本
- 8 个分类（主粮/零食/医疗/美容洗护/玩具/用品/保险/其他），可挂到具体宠物或"全体"
- 月度汇总大数字、分类占比、趋势图、月均消费
- 明细 CSV 导出（带 BOM，Excel 中文友好）

### 云空间（可选）
- 纯对象存储加密共享：空间暗号 + 三级角色（所有者/管理者/成员）
- 变更检测 + 改前拉取的同步引擎，六页手动同步按钮
- AI 对话记录**不**纳入云同步（隐私）

### 数据安全
- AI API Key 存系统钥匙串/Keystore（flutter_secure_storage），数据库不落明文
- 单文件 JSON 备份（含图片 base64）、版本校验、覆盖/合并两种恢复、恢复前自动回滚
- 全部数据本机存储，无账号；云空间为可选项且内容加密

## 设计说明

视觉：**清爽活力系**——鲜薄荷绿 × 冷白画布，数据用 Manrope 数字字体，图标为 Phosphor Duotone 双色矢量。

- **主色**鲜薄荷绿 `#21A36B`：装饰/图标/选中态；文字级强调与实底按钮使用加深档（`#17724B` 系），全部文字/背景配对实测 WCAG AA（≥4.5:1）
- **双主题**：浅色 = 纯白画布 + 微暖瓷片；深色 = 暖灰 `#3B3535` 家族；跟随系统，可手动固定
- **语义色门面**（`ChongjiPalette`）：页面统一 `context.palette.xxx` 取色，主题调整只动 `theme.dart` 一个文件
- 点缀色为同明度低饱和家族（鼠尾草/杏黄/天蓝/薰衣草/珊瑚），仅用于图表与分类，杜绝彩虹感
- **字阶**（`AppTheme`）：正文 15px 达标线，大数字 Manrope 等宽（`displayNumber` 56px 展示级 / `bigNumber` 20px 数据级），细字重承载高级感
- 动效克制：全局 150/250ms + easeOutCubic，底导选中弹跳、按压缩放、删除重触感

## 页面地图

| 页面 | 路由 |
|---|---|
| 引导 | `/onboarding` |
| 首页 | `/home` 照片轮播、核心信息、AI 关注、到期、时刻 |
| 健康 | `/health` 体重曲线、BCS、疫苗驱虫卡、按月分组记录 |
| 健康记录表单 | `/health/record/new`、`/health/record/:id/edit` |
| 时间线 | `/timeline`、`/moment/new`、`/moment/:id/edit` |
| 饮食 | `/diet`、`/diet/preferences` |
| 账本 | `/expenses`、`/expense/new`、`/expense/:id/edit` |
| 宠物 | `/pet/new`、`/pet/:id`、`/pet/:id/edit` |
| AI | `/ai/chat`、`/ai/quick-add`、`/ai/weekly` |
| 设置 | `/settings`、`/settings/ai`、`/settings/carousel`（首页轮播图）、`/settings/backup`、`/settings/cloud`、`/settings/about` |

底部导航：**首页 / 健康 / ＋（中央爪印钮：健康记录/时刻/消费/AI 一句话）/ 饮食 / 时刻**，悬浮毛玻璃小岛。

## 技术栈

| 用途 | 选型 |
|---|---|
| 框架 | Flutter 3.32+ / Dart 3.8 |
| 状态管理 | flutter_riverpod |
| 路由 | go_router（StatefulShellRoute + 中央圆钮） |
| 数据库 | Drift + sqlite3_flutter_libs（schema v4，迁移自动） |
| 图片 | image_picker（压缩 82%/1600px，存 App 私有目录）+ EXIF 读取 |
| 图表 | fl_chart |
| 图标 | phosphor_flutter（Duotone 双色矢量，结构层统一） |
| 字体 | Manrope（数字/拉丁，离线打包 3 字重） |
| AI | http（OpenAI 兼容 `/chat/completions`，含 SSE 流式与 function calling） |
| 通知 | flutter_local_notifications + timezone（每日摘要预排 7 天） |
| 云存储 | 纯对象存储 SigV4 直连（可选） |
| 密钥 | flutter_secure_storage（encryptedSharedPreferences） |

## 项目架构

```
lib/
├── main.dart
├── app/          theme(ChongjiPalette/AppTheme/Motion) / router / app_shell / providers / app_settings / image_store
├── core/
│   ├── ai/       ai_client(阻塞+SSE流式+tools) / ai_config / ai_prompts / ai_service
│   ├── constants/ app_info / breeds(品种体重区间) / bcs(1-9图解)
│   ├── notifications/  到期提醒 + 每日摘要（NotificationService）
│   └── utils/    formatters / money(int 分)
├── data/
│   ├── db/       tables / app_database(schema v4 自动迁移)
│   └── repositories/  pet / health_record / moment / expense / diet / settings / backup
├── domain/
│   ├── models/   pet / health_record / moment / expense / diet_profile / meal_plan / enums
│   └── services/ health_calculator(含 dailyDigestText) / diet_calculator / statistics_service（纯函数 + now 注入）
├── features/     onboarding / home / health / timeline / diet / expenses / pets / settings / ai
└── shared/widgets/  common(PageScaffold/SelectChip/DueBadge/FormSaveBar…) / photo_viewer / sync_button
```

分层原则：**页面不写业务计算**——年龄/下次到期/体重趋势/摘要文案走 `HealthCalculator`，热量估算走 `DietCalculator`，统计口径走 `StatisticsService`；全部纯函数、`{DateTime? now}` 注入，可直接单测。金额一律 int 分存储。

## 环境要求与运行

- Flutter 3.32+
- Android：Android Studio + Android SDK；iOS：Xcode 15+

```bash
cd chongji
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # 生成 Drift 代码（仅开发时）
flutter run
flutter build apk --release        # Android
```

## 测试

```bash
flutter test        # 88 个测试
flutter analyze     # 0 issues
```

覆盖：年龄/生活阶段/体重趋势/下次到期/生日推算、每日摘要文案（临近/过期/窗口过滤/多宠排序）、RER 与热量系数、消费统计口径、AI JSON 容错提取、一句话解析、金额精度、数据库往返、云空间同步（LWW/墓碑/加密）、模型序列化、深浅色组件渲染。

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
| 相册 | 仅在选择照片（时刻/记录/轮播图/小票）时 |
| 通知 | 开启提醒或每日摘要时（Android 13+ 启动时自动补弹授权） |

## 已知限制与路线图

- AI 计划质量依赖所配模型；弱模型的 JSON 输出可能解析失败（已做多级容错）
- 通知在 App 被强制结束后由系统调度，Android 部分厂商需允许自启动
- 路线图（不阻塞）：家庭共享权限细化、可穿戴设备数据、多语言、iPad 双栏
