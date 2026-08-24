# AI

```{toctree}
:maxdepth: 1
./local-ai-service.md
./agent.md
./production-deployment.md
```

## 学习笔记: 视频记录

## [从词向量到Transformer，AI大模型背后的原理，一个动画急速入门](https://www.bilibili.com/video/BV1nogs6qEZn/?share_source=copy_web&vd_source=2f16beddb156bf5939a7b19f9044d409)

场景:
轩辕养了一只__(A鹦鹉, B汽车, C熊猫, D苹果)

* N-gram: 通过词语组合预测下一个词(比如历史文章出现养了一只鹦鹉多, 养了一只苹果没有. 所以选A)

缺点: 无法理解语义关系. 依赖已经出现过的组合 A变成虎皮鹦鹉就失效了.

* 词向量: 通过给每个token一个多维向量, 知道虎皮鹦鹉和鹦鹉相关, 所以修复了N-gram的缺点

缺点: 通过固定上下文处理, 导致很久以前的数据直接丢弃, context很短

* RNN: 增加一个隐藏状态, 每个token来都刷新当前状态向量. 修复了词向量没有记忆的问题.    

缺点: 只有一个隐藏状态, 长期信息无法报错

* LSTM: 增加细胞状态,模型控制. 在RNN基础上, 保留VIP信息. 控制VIP信息的退出机制, 引入机制, 推理的挑选机制. 

缺点: 需要顺序计算, 无法大规模计算.  

* Transformer: 修复了LSTM的问题


## [Transformer是什么？2017年那篇“无人问津”的论文，为何成了今天AI爆炸的起点？10分钟速通AI论文天花板《Attention is all you](https://www.bilibili.com/video/BV1G4iMBeEWH/?share_source=copy_web&vd_source=2f16beddb156bf5939a7b19f9044d409)  

![ScreenShot_2026-08-23_233211.png](./img/ScreenShot_2026-08-23_233211.png)

遇到这种翻译问题, 每个拉的含义不一样, 怎么处理呢?  

把句子分成token: 货拉拉 拉不拉 拉布拉多 .

1. 凭什么这么分, 可能也是根据token向量来的.  
2. 拉不拉怎么区分是 拉货的拉不拉还是拉拽的拉不拉.  
![ScreenShot_2026-08-23_233706.png](./img/ScreenShot_2026-08-23_233706.png)  
给每个token生成Q, K. 求value. value大说明二者比较接近. 比如此时拉不拉的拉拽和货拉拉的货运相乘就比较大, 所以货拉拉这里是运输工作, 拉不拉是拉货  
![ScreenShot_2026-08-23_233906.png](./img/ScreenShot_2026-08-23_233906.png)
![ScreenShot_2026-08-23_234128.png](./img/ScreenShot_2026-08-23_234128.png)
3. 顺序怎么办. 拉布拉多 拉不拉 货拉拉 就是不一样的意思了.  
从每个向量的值里找到最大的, 就是拉不拉的最新向量  
![ScreenShot_2026-08-23_234235.png](./img/ScreenShot_2026-08-23_234235.png)

![ScreenShot_2026-08-23_234826.png](./img/ScreenShot_2026-08-23_234826.png)
