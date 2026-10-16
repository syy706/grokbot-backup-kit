# grokbot-backup-kit

把 Grok Bot 盒子（box）上的技能、助手配置、偏好和工作区小文件**定时备份到你自己的私有 GitHub 仓库**，盒子重置后一键还原。
Back up a Grok Bot box's skills, agent configs, preferences and small workspace files to **your own private GitHub repo**, and restore them after a reset.

---

## 中文

### 它做什么
- `backup.sh`：按白名单收集文件 → 生成已装工具清单（pip / npm / apt / ~/.local/bin）→ 密钥扫描 → 数据仓库不存在则自动建**私有**仓库 → 有改动才提交推送。工具本身也会复制到数据仓库的 `kit/` 里，方便还原。
- `restore.sh`：默认只演练（列出 NEW / CHANGED），加 `--apply` 才覆盖；覆盖前旧文件存到 `~/.pre-restore/<时间戳>/`，然后按清单重装工具（`--no-tools` 跳过）。
- `collect.py`：顶部 **CONFIG** 区是白名单和排除规则，按需修改。

### 备份什么 / 不备份什么
| 备份 | 不备份 |
|---|---|
| `agent-data/workflows`、`plugin-skills`（技能） | 密码、cookie、token、密钥、`.env`、`~/.ssh`、gh 配置 |
| 各助手的 `*.json` 配置、<5MB 的 `store.db` 快照 | 名字含 token/secret/cookie/key/credential 的文件 |
| 插件配置（plugin.json / mcp.json 等） | 视频图片等大文件、venv、node_modules、缓存、模型 |
| `/workspace` 下 ≤1MB 的文本/代码文件 | 服务器端的记忆与定时任务（本来就不会丢） |

### 安全
- 敏感文件按名称一律排除；推送前再做正则密钥扫描（GitHub / OpenAI / AWS / Slack token、私钥、明文 password 赋值），命中即**中止推送**。
- token 只通过环境变量 + `GIT_ASKPASS` 传给 git，不写入 URL、文件或 git config。
- **数据仓库务必设为私有**（脚本自动创建时即为私有）。本仓库（工具）是公开的，你的数据不在这里。

### 准备 token
- **Classic PAT**（最省事）：GitHub → Settings → Developer settings → Tokens (classic)，只勾 `repo`。
- **Fine-grained**：Repository access 选 All repositories（或选中已建好的数据仓库），权限 Contents 与 Administration 设为 Read and write（Administration 用于自动建仓库）。

### 使用
```bash
git clone https://github.com/syy706/grokbot-backup-kit ~/backup-kit
export GITHUB_BACKUP_TOKEN=...        # 不要写进文件
export BACKUP_GH_USER=<你的GitHub用户名> BACKUP_REPO=<私有数据仓库名，如 my-box-backup>
~/backup-kit/backup.sh --dry-run      # 只列出将备份的文件并扫描
~/backup-kit/backup.sh                # 正式备份
```
可选环境变量：`BACKUP_HOME`（默认 `/home/box`）、`BACKUP_WORKSPACE`（默认 `/workspace`）、`BACKUP_EXTRA_EXCLUDE_DIRS="dir1,dir2"`。

### 在空白盒子上还原（一行引导）
```bash
A=$(mktemp); printf '#!/bin/sh\ncase "$1" in U*) echo x-access-token;; *) echo "$GITHUB_BACKUP_TOKEN";; esac\n' >$A; chmod +x $A; rm -rf /tmp/gb && GIT_ASKPASS=$A GIT_TERMINAL_PROMPT=0 git clone -q https://github.com/$BACKUP_GH_USER/$BACKUP_REPO.git /tmp/gb; rm -f $A; bash /tmp/gb/kit/restore.sh
```
确认演练结果后：`bash /tmp/gb/kit/restore.sh --apply`。

### 定时
- Grok Bot：让助手建一个定时任务（routine），例如「每天 23:00 用 Box backup and restore via GitHub 技能备份」。
- cron 示例：`0 23 * * * BACKUP_GH_USER=me BACKUP_REPO=my-box-backup GITHUB_BACKUP_TOKEN=$(cat ~/.config/backup-token) ~/backup-kit/backup.sh >>/tmp/backup.log 2>&1`（token 文件权限设 600，且别放进备份范围——文件名含 token 会被自动排除）。

### 安装技能（Grok Bot 用户）
把 `skill/SKILL.md` 内容发给你的 Grok Bot，说「把这个存成技能」；或复制到 `/home/box/agent-data/workflows/box-backup-and-restore-via-github/SKILL.md`。然后说「备份我的盒子到 GitHub」即可。

---

## English

### What it does
- `backup.sh [--dry-run]`: collects allowlisted files, writes a tool manifest, runs a secret scan, creates the **private** data repo if missing, commits and pushes only on changes. The kit is copied into `kit/` of the data repo for bootstrapping.
- `restore.sh [--apply] [--no-tools]`: dry run by default; `--apply` overwrites after saving current files to `~/.pre-restore/<ts>/`, then reinstalls tools from the manifest.
- `collect.py`: the **CONFIG** block at the top holds the allowlist and exclusions.

### Backed up / not backed up
Backed up: skills (`workflows`, `plugin-skills`), per-agent JSON configs, small `store.db` snapshots, plugin configs, text/code files ≤1 MB in `/workspace`.
Never: passwords, cookies, tokens, keys, `.env`, `~/.ssh`, gh config, files whose names contain token/secret/cookie/key/credential, large media, venvs, node_modules, caches, models. Server-side memory and routines are not needed.

### Safety
Name-based exclusion + regex secret scan before every push (aborts on a hit). Token is passed only via env and `GIT_ASKPASS`, never in URLs, files or git config. **Keep your data repo private.**

### Token
Classic PAT with the `repo` scope, or a fine-grained token with Contents + Administration read/write.

### Usage
```bash
git clone https://github.com/syy706/grokbot-backup-kit ~/backup-kit
export GITHUB_BACKUP_TOKEN=... BACKUP_GH_USER=<you> BACKUP_REPO=<private-data-repo>
~/backup-kit/backup.sh --dry-run && ~/backup-kit/backup.sh
```
Optional: `BACKUP_HOME`, `BACKUP_WORKSPACE`, `BACKUP_EXTRA_EXCLUDE_DIRS`.

### Restore on a blank box
Run the one-liner from the Chinese section above, review the dry run, then `bash /tmp/gb/kit/restore.sh --apply`.

### Scheduling
Ask Grok Bot to create a daily routine using the skill, or use the cron example above.

### Install the skill (Grok Bot)
Send `skill/SKILL.md` to your Grok Bot and ask it to save it as a skill, or copy it to `/home/box/agent-data/workflows/box-backup-and-restore-via-github/SKILL.md`.

## License
MIT
