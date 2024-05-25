# gnome显示设置
## 更换图标的显示位置
    gsettings set com.canonical.Unity.Launcher launcher-position Bottom/Left
## 使用workspace
    gsettings set org.compiz.core:/org/compiz/profiles/unity/plugins/core/ vsize 2  # 设置workspace的行列数
    gsettings set org.compiz.core:/org/compiz/profiles/unity/plugins/core/ hsize 2

## 更换背景图
    gsettings get org.gnome.desktop.background picture-uri
    gsettings set org.gnome.desktop.background picture-uri 'file:///home/wangx/Pictures/臆羚.jpg'
