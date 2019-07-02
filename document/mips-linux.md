# MIPS Linux 移植

## 缺少的指令

ssnop

## 需要做的事情

弄明白linux 2.6.38内核,学会给内核写makefile,使用mipsel-linux-gcc生成运行linux的coe(应该做完就能启动linux?)

### Makefile

164行开始是关于交叉编译器的内容
$@--目标文件，$^--所有的依赖文件，$<--第一个依赖文件
