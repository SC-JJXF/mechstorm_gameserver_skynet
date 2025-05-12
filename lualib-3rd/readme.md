本文件夹应由 luarocks 管理。

你可以使用 luarocks 像前端 npm/yarn 那样为项目添加你需要的依赖。

示例：

```bash
# --lua-version=5.4 指定和本项目所用skynet相同的lua版本
luarocks install --to ./lualib-3rd/ --lua-version=5.4 bump-3dpd

luarocks install --to ./lualib-3rd/ --lua-version=5.4 https://raw.githubusercontent.com/kyleconroy/lua-state-machine/refs/heads/master/statemac
hine-1.0.0-1.rockspec
```