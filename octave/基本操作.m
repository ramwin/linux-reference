% 逻辑运算
    1 == 2  % 注释
    1 ~= 2

a = pi;
PS1('>> '); % 修改发送的请求
disp(a);    % 显示a
disp(sprintf('2 decimals: %0.2f', a))   % 格式化输出
format long % 默认输出完整小数
format short    % 输出短的小数

A = [1 2; 3 4; 5 6] % 定义矩阵
v = 1:0.1:2     % 从1 到2 间距为 0.1的序列 。包括1 和2
ones(2,3)   % 2 x 3 的矩阵(都为1)
rand(3,3)   % 3 x 3 的随机数矩阵
randn(3,3)  % 高斯分布的矩阵
w = -6 + sqrt(10)*(randn(1,10000))
hist(w) % 显示 w 的分布
hist(w,50)  % 后面数字表示分成多少个柱形图
eye(4)  % 生成一个 identify matrix

who % 展示有哪些数据
whos
A = [1 2;3 4;5 6]
size(A) % 返回矩阵的大小，返回的也是一个 1 x 2矩阵
size(A, 1) % 返回矩阵的行数
v = [1 2 3 4] % 返回矩阵最长的维度, 一般用于 vector
A(3,2)  % 举证第三行第二列数据

pwd % 当前目录
cd  % 修改目录
ls  % 展示当前的文件
load <filename>     % 导入文件内的数据
load('filename')    % 同上
clear <variabl>     % 清除一个变量
v = A(1:10)  % 返回Ａ的第一个到第十个的数据,一般用于 vector
save hello.mat A;   % 保存数据到文件 二进制
    save hello.txt v -ascii % 通过ASICC码进行保存数据, 无变量名了
load hello.mat; % 载入之前保存的变量(并且变量名不变)
