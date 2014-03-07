xrandr --newmode "1280x720@60" 74.48 1280 1336 1472 1664 720 721 724 746 -HSync +Vsync 
xrandr --addmode VGA1 "1280x720@60"
xrandr --output LVDS1 --mode "1366x768" --output VGA1 --above LVDS1 --mode "1280x720@60"
