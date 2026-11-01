# 部署与上线

整个系统是一个 Node.js 服务（API + H5 网页）加一个 SQLite 数据文件。推荐顺序：

1. **现在**：部署 H5 网页版，发链接给大陆的朋友和老师们试用；
2. **试用满意后**：由有大陆身份的朋友注册微信小程序，用同一套代码编译上传。

## 一、Docker 部署（推荐）

```bash
git clone <本仓库> lianghua && cd lianghua
cp .env.example .env        # 按需修改，至少设置 JWT_SECRET
docker compose up -d --build
```

访问 `http://服务器IP:8787`。数据保存在 `./data/lianghua.db`。

大陆服务器拉取 Docker Hub 或 npm 较慢时，可以换用国内镜像：

```bash
docker build \
  --build-arg NODE_IMAGE=<国内镜像源>/library/node:22-alpine \
  --build-arg NPM_REGISTRY=https://registry.npmmirror.com \
  -t tzsz-lianghua .
```

### 正式上线前检查

```ini
# .env
PUBLIC_URL=https://lh.example.com
JWT_SECRET=<openssl rand -hex 32 生成>
AUTH_DEMO=false
SEED_DEMO=false            # 配合空的 data 目录，启动日志会打印首个管理员邀请码
AUTH_ISSUER=...            # 你的身份平台，见 docs/AUTH.md
```

然后在管理后台依次：系统设置（学校名称、学期开始日期）→ 班级 → 教职工 → 学生（可从 Excel 批量粘贴导入）→ 宿舍 → 检查一遍量化细则与重大违纪类型（重大违纪的扣分在「系统设置」中统一设定，默认 10 分）。

## 二、不用 Docker

需要 Node.js ≥ 22.13（使用了内置的 `node:sqlite`，无需编译任何原生模块）。

```bash
npm run setup
npm run build
npm start                  # 或用 pm2：pm2 start "npm start" --name lianghua
```

## 三、HTTPS 与域名（Nginx 示例）

```nginx
server {
  listen 443 ssl http2;
  server_name lh.example.com;
  ssl_certificate     /etc/nginx/cert/lh.pem;
  ssl_certificate_key /etc/nginx/cert/lh.key;

  location / {
    proxy_pass http://127.0.0.1:8787;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
```

注意：在大陆的服务器上用域名对外提供网站，域名需要完成 **ICP 备案**；小程序的服务器域名也必须是备案过的 HTTPS 域名。

## 四、先给朋友试用（不需要备案）

在大陆还没有服务器时，可以先把 Docker 镜像部署到海外或香港的云平台（如 Render、Railway、Fly.io 或任意 VPS），保持 `AUTH_DEMO=true` 让大家用演示账号体验。注意：

- 免费平台通常没有持久磁盘，重启后数据会恢复为演示数据，只适合演示；
- 海外服务器在大陆访问可能较慢；在微信里直接打开未备案的链接，可能会出现安全提示或被拦截，可让对方复制到手机浏览器打开。

## 五、数据备份

SQLite 只有一个文件。最简单的做法是每天定时复制：

```bash
# crontab -e
0 3 * * * sqlite3 /path/to/data/lianghua.db ".backup /path/to/backup/lianghua-$(date +\%F).db"
```

没有安装 sqlite3 时，可以先停止服务再复制 `lianghua.db`。

## 六、上线微信小程序（交给有大陆身份的朋友）

小程序必须由有大陆身份或组织资质的主体注册，代码可以由你继续维护。大致流程：

1. **注册小程序**：在 [微信公众平台](https://mp.weixin.qq.com) 注册小程序，完成认证和**小程序备案**，得到 AppID。选择服务类目时，教育相关类目可能要求学校或机构资质，个人主体可选的类目有限，请以平台审核要求为准；如能以学校名义注册最稳妥。
2. **配置服务器域名**：小程序后台 → 开发管理 → 开发设置 → 服务器域名，把后端的 HTTPS 域名同时加入 **request 合法域名** 和 **downloadFile 合法域名**（导出 Excel 用）；同时在服务器 `.env` 填写 `WX_APPID` 和 `WX_SECRET`。
3. **编译**：
   ```bash
   # app/.env
   VITE_API_BASE=https://lh.example.com
   ```
   在 `app/src/manifest.json` 的 `mp-weixin.appid` 填入 AppID，然后：
   ```bash
   npm run build:mp       # 输出到 app/dist/build/mp-weixin
   ```
4. **上传**：用 [微信开发者工具](https://developers.weixin.qq.com/miniprogram/dev/devtools/download.html) 导入 `app/dist/build/mp-weixin`，在真机上预览测试后点「上传」，再到后台提交审核、发布。项目已开启「增强编译」以支持新版 JavaScript 语法。
5. **登录**：用户在网页端登录后生成绑定码，在小程序中绑定一次即可，见 [AUTH.md](AUTH.md#5-微信小程序登录)。

> 说明：H5 版本已经用浏览器完整测试过；小程序版本能正常编译，但小程序环境与浏览器有差异，上线前请在开发者工具和真机上把主要页面都点一遍。

### 不想做小程序？

H5 网页本身就能在微信里使用：把链接设置到学校公众号的菜单，或发到家长群即可。只要域名已备案，体验和小程序接近。

## 七、个人信息保护

系统中有大量未成年人的个人信息（姓名、班级、宿舍、成绩、处分）。建议：

- 由学校授权使用，并告知家长收集和使用的范围；
- 服务器和数据放在大陆境内；
- 只开放必要的账号，教师离职后及时停用；
- 家长端默认不显示年级排名，可在设置中调整。
