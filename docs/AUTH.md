# 接入你的登录平台

本系统自己不保存密码，登录交给你的身份平台完成，系统只负责「这个人在学校里是谁」。

支持以下登录方式，可以同时开启：

| 方式 | 适用场景 | 开关 |
| --- | --- | --- |
| 用 e 账户登录（yeraldo.com） | 正式使用：网页版与微信小程序 | 配置 `E_CLIENT_ID`（见下一节） |
| 其他身份平台（OIDC / OAuth 2.0） | 正式使用，H5 网页（含微信内打开） | 配置 `AUTH_ISSUER` 或三个 URL |
| 演示账号 | 测试、给朋友体验 | `AUTH_DEMO=true`（**上线前务必关闭**） |
| 微信小程序 | 小程序上线后免登录 | 配置 `WX_APPID`、`WX_SECRET` |

## 用 e 账户登录（yeraldo.com）

按 e 的《用 e 账户登录：接入规范》实现。本系统属于两类：

| 端 | 规范中的类型 | 流程 |
| --- | --- | --- |
| 网页版（H5，含在微信里打开） | §3A 有后端的网站 | 点「用 e 登录」→ e 授权页 → 回到本系统 |
| 微信小程序 | §6 小程序 | 小程序显示登录链接二维码 → 用浏览器登录 e → 小程序自动等到结果 |

两者用同一个回调地址。

### 你需要在 e 上做的

1. 在 <https://yeraldo.com/developers> 创建应用（账户需要蓝 V、金 V 或灰 V 认证）。
2. 登记回调地址（最多 5 个）：
   - 正式：`https://你的域名/auth/e/callback`（就是 `PUBLIC_URL` 加 `/auth/e/callback`，必须完全一致，不能多斜杠，http/https 也要一致）
   - 本地测试：`http://localhost/auth/e/callback`（回环地址不写端口，运行时用 8787 端口也能匹配）
3. 把应用的 `client_id` 填进 `.env`：

   ```ini
   PUBLIC_URL=https://你的域名
   E_CLIENT_ID=应用的 client_id
   E_BETA_SOFTWARE=软件的 slug   # 需要检查内测资格时才填
   ```

4. 需要内测资格时：在 e 上发布这个软件（必须是创建应用的同一个 e 账户），把老师、家长的 e 账户加进内测成员；批量创建账户时选「加入软件内测成员」的会直接通过。

### 系统怎么做的

- 授权请求：`response_type=code`、PKCE（S256）、随机 `state`，`scope` 为 `profile`（填了 `E_BETA_SOFTWARE` 时为 `profile beta`）。没有 client_secret。
- 回调：核对 `state`，并且 `state` 与发起登录的浏览器绑定（HttpOnly、SameSite=Lax 的 Cookie），防止别人把自己的回调链接发给你；每个回调只能用一次。用户在 e 上点「取消」时回到登录页提示「你取消了授权」。
- 换令牌、读资料、查内测都在服务端；用 `sub` 作为 e 账户的永久 ID（`users.e_sub` 唯一索引），用户名、头像每次登录时更新。第一次用 e 登录的人还要在本系统里认领身份：老师输入管理员给的**邀请码**，家长输入孩子的**绑定码**。
- e 的令牌加密（AES-256-GCM）后存在数据库 `e_sessions` 表，每次登录（每台设备）一组；浏览器只拿到本系统自己的登录令牌，地址栏里只出现一次性的兑换码。
- 每次打开应用时复查（默认最多每 5 分钟一次）：访问令牌过期就用刷新令牌续期，并保存 e 返回的新刷新令牌；查内测资格（或读一次用户资料）。在 e 的「设置 → 已授权的应用」撤销授权、或被移出内测后，下次打开应用即回到登录页并提示原因。连不上 e 时沿用最近一次结果，但不超过 24 小时。
- 退出登录时撤销这次登录在 e 上的授权。
- 小程序：`POST /api/auth/e/start` 生成 5 分钟有效、只能用一次的登录链接和轮询用的 `poll_id`（不在链接里），小程序显示二维码并提供「复制链接」，每 2 秒请求 `GET /api/auth/e/poll`，完成后拿到本系统的登录令牌（只返回一次）。e 的令牌不下发给小程序。小程序只需把你自己的后端域名登记为「服务器域名」，不需要请求 yeraldo.com。

### 本地自测

`server/tools/mock-e.js` 按规范模拟了 e 的授权服务器（授权页、换令牌、刷新轮换、用户资料、内测资格、撤销）。`npm test` 会对着它跑一遍验收清单；也可以手动试：

```bash
node server/tools/mock-e.js 9911 测试用client_id http://localhost/auth/e/callback lianghua
E_CLIENT_ID=测试用client_id E_BASE_URL=http://127.0.0.1:9911 E_BETA_SOFTWARE=lianghua npm start
```

`E_BASE_URL` 只在对着模拟服务测试时设置，正式环境不要填。

## 1. 平台需要支持什么

平台需要支持 **OAuth 2.0 授权码模式**（Authorization Code），最好同时支持 **OIDC**。常见的 Casdoor、Logto、Authing、Keycloak、Zitadel、Authentik，以及大多数自建 SSO 都支持。

> 如果你的平台不是 OAuth（例如只提供「用户名 + 密码换 token」的接口，或者通过请求头传递用户），也很容易接：所有登录方式最终都调用 `server/src/auth.js` 中的 `resolveExternalUser(claims)`，只要拿到平台返回的用户 ID 和姓名即可。把平台的接口文档发给我，可以加一个适配器。

## 2. 在平台中创建应用

在平台后台新建一个「Web 应用 / OAuth 客户端」，记下 **Client ID** 和 **Client Secret**，并登记回调地址（Redirect URI）：

```
https://你的域名/api/auth/oidc/callback
```

本地测试时为 `http://localhost:8787/api/auth/oidc/callback`。授权范围（scope）一般勾选 `openid profile email phone`。

## 3. 填写 .env

把仓库根目录的 `.env.example` 复制为 `.env`：

```ini
PUBLIC_URL=https://lh.example.com
AUTH_LABEL=使用 XX 平台登录          # 登录按钮上的文字

# 平台支持 OIDC：只需填 issuer（系统会读取 /.well-known/openid-configuration）
AUTH_ISSUER=https://id.example.com
AUTH_CLIENT_ID=xxxxxxxx
AUTH_CLIENT_SECRET=xxxxxxxx

# 平台只支持 OAuth 2.0：不填 AUTH_ISSUER，改填这三个地址
# AUTH_AUTHORIZE_URL=https://id.example.com/oauth/authorize
# AUTH_TOKEN_URL=https://id.example.com/oauth/token
# AUTH_USERINFO_URL=https://id.example.com/api/userinfo
```

重启后，登录页会出现「使用 XX 平台登录」按钮。

其他可选项：

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `AUTH_TOKEN_AUTH_METHOD` | `client_secret_post` | 平台要求 HTTP Basic 认证时改为 `client_secret_basic` |
| `AUTH_PKCE` | `true` | 平台不支持 PKCE 时设为 `false` |
| `AUTH_SCOPE` | `openid profile email phone` | |
| `AUTH_REDIRECT_URI` | `${PUBLIC_URL}/api/auth/oidc/callback` | |
| `AUTH_CLAIM_SUB` | `sub` | 用户唯一 ID 的字段名，例如 `id`、`data.uid` |
| `AUTH_CLAIM_NAME` | `name` | 姓名字段 |
| `AUTH_CLAIM_PHONE` | `phone_number` | 手机号字段（用于自动关联教师账号） |
| `AUTH_CLAIM_EMAIL` | `email` | 邮箱字段 |
| `AUTH_CLAIM_ROLE` | 空 | 角色字段（见下文「角色也由平台管理」） |
| `AUTH_ROLE_MAP` | 空 | 平台角色到本系统角色的映射 |

系统优先调用平台的 userinfo 接口获取用户信息；没有 userinfo 接口时读取 id_token 中的字段。如果平台把用户信息包在 `data` 字段里（不少国内平台如此），会自动展开。

## 4. 平台账号如何对应到学校里的身份

第一次用平台登录时，系统按以下顺序查找：

1. **已绑定过**：平台用户 ID 一致 → 直接登录。
2. **手机号/邮箱一致**：管理员在「教职工」里预先填了手机号，平台返回的手机号相同 → 自动关联为该教师。
3. **都不匹配**：创建一个「待绑定」账号，进入「完成身份绑定」页面：
   - **教师**：输入管理员在「管理后台 → 教职工」新建账号时生成的**邀请码**；
   - **家长**：输入班主任在「班级 → 绑定码」中查到的孩子的**绑定码**，并选择与孩子的关系。一个家长可以绑定多个孩子，一个孩子最多绑定 6 位家长。

系统只有教师（含管理员）和家长两类用户，学生本人不需要登录。

绑定码 8 位，不含容易混淆的 0/O、1/I/L，输错有频率限制。怀疑泄露可随时重置，已绑定的家长不受影响。

### 首个管理员

正式部署使用空数据库并设置 `SEED_DEMO=false`，首次启动时日志会打印：

```
首个管理员邀请码：XXXXXXXX
```

用平台登录后输入该邀请码即成为管理员，然后再去创建其他教师。

### 角色也由平台管理（可选）

如果你的平台里已经给用户分好了角色（例如分组 `school-admin`、`teacher`），可以让系统直接采用：

```ini
AUTH_CLAIM_ROLE=roles                    # 平台返回角色的字段名，支持数组或逗号分隔字符串
AUTH_ROLE_MAP=school-admin:admin,teacher:teacher,parent:parent
```

这样教师首次登录就直接是教师身份，不需要邀请码；每次登录都会按平台同步角色。班主任、任课班级等学校内部信息仍在本系统中设置；家长仍需用绑定码关联孩子。

## 5. 微信小程序登录

小程序里无法跳转到网页登录，因此采用「绑定一次、以后免登录」：

1. 用户先在 H5 网页端用身份平台登录，进入「我 → 绑定微信小程序」，得到 6 位绑定码（10 分钟有效）；
2. 打开小程序，点「微信登录」，输入绑定码，完成绑定；
3. 以后在小程序中点「微信登录」直接进入。

服务器需要配置小程序的 `WX_APPID` 和 `WX_SECRET`（小程序后台 → 开发管理 → 开发设置）。

## 6. 安全建议

- 正式上线：`AUTH_DEMO=false`，并设置随机的 `JWT_SECRET`（`openssl rand -hex 32`）；
- 全程使用 HTTPS，回调地址必须与平台中登记的完全一致；
- 登录回调只会跳回 `FRONTEND_URL`，令牌不会出现在网址里（回调页用一次性登录码换取令牌）；
- 停用教师账号：管理后台 → 教职工 → 停用，立即失效。
