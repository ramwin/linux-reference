A * C   % 矩阵乘法
A .* B  % 对应位置的乘法
A .^ 2  % 每个元素阶乘
v = [1; 2; 3]
1 ./ v  % 把1除以每一个元素 element wise 操作
log(v)
exp(v)
v+1 % 把每个元素加1
A'  % 转置矩阵
max(A)  % 
[val, index] = max(a)   % 获取最大的和他的索引
a = [1 15 2 0.5]
a < 3   % element wise comparision return [1 0 1 1]
find(a < 3) % return [1 3 4]    哪些数据小于3
magic(n)    % 返回一个横竖，斜对焦相加都一样的矩阵
A = magic(3)
[r, c] = find(A>=7)
sum(a)  % 求和
prod(a) % 乘积
floor(a)    ceil(a) % 两种取整数
max(A, [], 1)   % 取出没一列的最大值
max(A, [], 2)   % 取出每一行最大值
max(max(A)) % 取出最大值，下面的也是
A(:)    % 把A变成一个vector
max(A(:))
flipud(A)   % 把A上下翻转
prinv(A)    % 返回逆矩阵
