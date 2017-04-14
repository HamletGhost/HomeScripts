#
# ,-------------------------.
# |                         |
# |       1920 x 1080       |
# |                         |
# |                         |
# `-----,-------------,-----'
#       |             |
#       | 1366 x 768  |
#       |  (primary)  |
#       |             |
#       `-------------'
#
# xrandr --output LVDS1 --mode 1366x768 --pos 277x1080 --output VGA1 --preferred --rotate normal

#               ,---------.
# ,-------------|         |
# |             |         |
# | 1366 x 768  |         |
# |  (primary)  |  1080   |
# |             |    x    |
# `-------------|  1920   |
#               |         |
#               | (auto)  |
#               |         |
#               |         |
#               '---------'
xrandr --output LVDS1 --preferred --rotate normal --output VGA1 --preferred --rotate left
