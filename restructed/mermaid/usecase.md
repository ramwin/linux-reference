# 用例图

* mermaid 12.0 起原生支持用例图, 用 `usecase-beta` 关键字(语法: [usecase](https://mermaid.js.org/syntax/usecase.html)):
    * `actor ID("显示名")` 画小人, 标识符只能用 `[A-Za-z0-9_]`, 中文要写显示名里
    * `UC("用例")` 是椭圆用例, `UC[用例]` 是矩形用例
    * `systemBoundary 边界ID["标题"] ... end` 表示模块(系统边界)
    * 关联用无向的 `A -- B`; 另有 `-->`, `--|>`(泛化), `..> : include` / `..> : extend`
    * 默认用 ELK 布局(不用 dagre), redux-color 主题 + neo 外观

## 中心发散型

5 个 actor 放中间一排, 8 个模块分上下两排(上 4 下 4), 每个 actor 关联 3~4 个用例。

ELK 和 dagre 一样按边的方向分层: 谁写在前谁排在上一层。所以上排模块写成 `UC -- actor`, 下排模块写成 `actor -- UC`, actor 就落在中间一层, 关联线向四周发散。

布局结果宽高比约 1.9:1, 网页上不会出现过宽压扁的问题。

```{mermaid}
usecase-beta
direction TB
%% 上排 4 个业务模块
systemBoundary UserModule["用户管理模块"]
  Login("注册与登录")
end
systemBoundary GoodsModule["商品管理模块"]
  Browse("浏览与搜索商品")
end
systemBoundary OrderModule["订单管理模块"]
  Order("下单与退换货")
end
systemBoundary PayModule["支付管理模块"]
  Pay("发起支付")
end
%% 中间的 5 个 actor
actor User("普通用户")
actor Guest("访客")
actor Admin("管理员")
actor Ops("运营人员")
actor Auditor("审核员")
%% 下排 4 个支撑模块
systemBoundary MsgModule["消息通知模块"]
  Msg("发送与接收消息")
end
systemBoundary StatsModule["数据统计模块"]
  Stats("查看统计报表")
end
systemBoundary PermModule["权限管理模块"]
  Perm("分配角色权限")
end
systemBoundary ConfModule["系统设置模块"]
  Conf("修改系统配置")
end
%% 上排模块: 写在前面的排在上一层
Login -- User
Login -- Admin
Login -- Guest
Browse -- User
Browse -- Ops
Browse -- Guest
Order -- User
Order -- Auditor
Pay -- User
%% 下排模块: actor 写在前面
Admin -- Stats
Admin -- Perm
Admin -- Conf
Auditor -- Msg
Auditor -- Stats
Auditor -- Perm
Ops -- Msg
Ops -- Stats
Ops -- Conf
Guest -- Stats
```
