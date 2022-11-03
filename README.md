# JARUNNER

<pre>
   __
   \ \__ __ ___   ____
    \ \ /_` || '__|| | | || '_ \
 /\_/ /| (_| || |   | |_| || | | |
 \___/  \__,_||_|    \__,_||_| |_| 1.0.0

Usage: jarun.sh COMMAND [service1] [service2]

Commands:
        config          Show the configuration of one or more services
        start           Start one or more services
        stop            Stop one or more services
        restart         Restart one or more services
</pre>

## 配置

### 应用配置

配置文件`config/services.ini`:

```ini
# 全局配置
[global]
mode = nohup        ; 运行方式 nohup or docker， 默认为 nohup
#log_dir = ./logs/  ; 日志目录
#env = prod         ; 运行环境
#user=root          ; 在远程主机上运行时使用的用户名（需要免密）

# 以下为具体应用配置
[sample-jar]
name = sample-jar    ; service name
port = 8081          ; Server port
jar = sample         ; 将在应用目录中搜索 sample-.*jar , launcher等于true时无效
profiles = dev       ; Spring boot active profile
#path = sample-jar   ; 应用目录，默认与name一样
#hosts = localhost   ; 运行在哪些主机上，默认localhost
#args = '-dsprin=aa' ; 应用参数
#launcher = true     ; jar launcher模式
#libs_dir = libs     ; jar launcher模式时要指定的loader.path目录
#log_dir = ./logs/   ; 目录目录，默认与全局日志目录一样
```

### 全局环境配置

1. 文件: `config/common.sh`。
2. `common` 目录下的所有`sh`文件。

> !!!!注意： 配置不可使用以下格式配置, 这将导致循环扩展(**Expansion**)。
>
> `export VA="${VA} other codes"`

### 应用个性化配置

文件: `your_app_dir/config/env.sh`

> !!!!注意： 配置不可使用以下格式配置, 这将导致循环扩展(**Expansion**)。
>
> `export VA="${VA} other codes"`
