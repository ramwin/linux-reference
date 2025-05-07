set -e
echo "exit"
./exit_with.sh 0 && ./exit_with.sh 121 && ./exit_with.sh 12
echo "之前的状态码是: " $?
echo "虽然之前的状态码不是0(2, 121, 128都会继续), 但是任务还是会继续执行"
echo "下面的ls会报错(2), 这个时候才会停止"
ls /ew
echo "exit"
