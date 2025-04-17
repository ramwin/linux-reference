set -e
echo "开始"
./exit_with.sh 0
a=$?
# a=3;
echo -n "a="
echo $a;
echo "正常OK";

echo "异常就无返回"
./exit_with.sh 1
a=$?
# a=3;
echo "a="
echo $a;
echo "结束"
