# Code Server

[code-server](https://github.com/coder/code-server) 在浏览器中运行的Visual Studio Code，支持远程访问。

## 使用说明

### 拉取Docker镜像

[Docker Hub](https://hub.docker.com/r/xczh/code-server/tags)

```
# ${tag}需替换，在上面的网站找
$ sudo docker pull xczh/code-server:${tag}
```

### 运行容器

可用的环境变量：
 - `PASSWORD` HTTP Basic Auth的明文密码，默认为`hello_coder`。
 - `HASHED_PASSWORD` HTTP Basic Auth的密码哈希值，默认为空。如该值非空，则忽略`PASSWORD`。使用[Argon2](https://argon2.online/)算法生成。
 - `CODE_ARGS` 附加启动参数，默认为空。

几点说明：
- 建议使用`--init`作为根进程
- 如需gdb调试，需开启`SYS_PTRACE`
- 如挂载本地磁盘作为volume，需检查权限是否正确

```sh
# 需确保 UID 1000 对volume拥有完全权限
$ mkdir -p ~/host-volume
$ chown -R 1000:1000 ~/host-volume

# 运行容器
$ sudo docker run -d --restart=unless-stopped \
                  --name code \
                  --hostname code-server \
                  --init \
                  --cap-add SYS_PTRACE \
                  -e PASSWORD=hello_coder \
                  -p 8080:8080 \
                  -v ~/host-volume:/volume \
                  xczh/code-server:${tag}
```
