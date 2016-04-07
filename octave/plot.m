t = [0:0.01:0.98]
y1 = sin(2*pi*4*t)
plot(t,y1);
y2 = cos(2*pi*4*t)
plot(t,y2);
hold on;    % 维持当前的图片，继续做图
xlabel('time');
ylabel('value');
legend('sin','cos') % 作线的标签
title('my plog')    % 标题
print -dpng 'myPlot.png'    % 保存到图片
close   % 关闭图片
figure(1); plot(t,y1);
figure(2); plot(t,y2);  % 在两个窗口显示图片
subplot(1,2,1)  % 把图片分成1 x 2的两个小窗口，并使用第一个
axis([0.5 1 -1 1])  %
clf;    % 清除图片
A = magic(5)
imagesc(A)  % 通过图片展示
imagesc(A), colorbar, colormap gray; % 根据数据大小显示灰度图
