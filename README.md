#### 快速开始

0. 你需要Linux环境。如果你在windows上，请安装使用WSL。

1. 克隆项目到本地

2. 运行 `git submodule update --init --recursive` 以拉取 skynet 子模块

3. 运行 `./skynet-compile.sh` 以编译本项目依赖的 skynet 框架

4. 运行 `./run.sh` 启动服务

> **Tip**  
> 本项目在运行时需要与 https://github.com/SC-JJXF/mechstorm_usercenter 实例通信来实现对所有入站连接 鉴权、恢复/更新 玩家物品、机甲信息（还没做）等功能。   
> 请将 `etc/config.lua`中的 usercenter_url 字段配置为该实例的 地址:端口（单服务器部署这两个的话默认的应该就能连上了）。

#### 开发 Tips

可以使用 Lua拓展 并启用 Lua拓展 中的 skynet addon 以获得更好的智能提示。


#### 特别鸣谢 Acknowledgements

[【从零开始学Skynet】实战篇《球球大作战》](https://blog.csdn.net/yangyu20121224/article/details/130139204) 、[配套源码](https://gitee.com/frank-yangyu/ball-server)

[基于 skynet 的 MMO 服务器设计](https://blog.codingnow.com/2015/04/skynet_mmo.html)

[大厅服如何对模块功能进行拆分隔离？](https://huahua132.github.io/2023/05/03/skynet_fly_word/word_4/D_q/)