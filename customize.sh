#!/bin/sh

SKIPUNZIP=1
ASH_STANDALONE=1

SURFING_PATH="/data/adb/modules/Surfing/"
SCRIPTS_PATH="/data/adb/box_bll/scripts/"
NET_PATH="/data/misc/net"
CTR_PATH="/data/misc/net/rt_tables"
CONFIG_FILE="/data/adb/box_bll/clash/config.yaml"
BACKUP_FILE="/data/adb/box_bll/clash/subscribe_urls_backup.txt"

if [ "$BOOTMODE" != true ]; then
  abort "Error: 请在 Magisk Manager / KernelSU Manager / APatch 中安装"
elif [ "$KSU" = true ] && [ "$KSU_VER_CODE" -lt 10670 ]; then
  abort "Error: 请更新您的 KernelSU Manager 版本"
fi

if [ "$KSU" = true ] && [ "$KSU_VER_CODE" -lt 10683 ]; then
  service_dir="/data/adb/ksu/service.d"
else
  service_dir="/data/adb/service.d"
fi

if [ ! -d "$service_dir" ]; then
  mkdir -p "$service_dir"
fi

extract_subscribe_urls() {
  if [ -f "$CONFIG_FILE" ]; then
    awk '/proxy-providers:/,/^profile:/' "$CONFIG_FILE" | grep -Eo "url: \".*\"" | sed -E 's/url: "(.*)"/\1/' > "$BACKUP_FILE"
    
    if [ -s "$BACKUP_FILE" ]; then
      echo "- 提取订阅地址已备份到"
      echo "- $BACKUP_FILE"
    else
      echo "- 未找到目标 URL，请检查配置文件格式"
    fi
  else
    echo "- 配置文件不存在，无法提取订阅地址"
  fi
}
restore_subscribe_urls() {
  if [ -f "$BACKUP_FILE" ] && [ -s "$BACKUP_FILE" ]; then
    awk 'NR==FNR {
           urls[++n] = $0; 
           next 
         }
         /proxy-providers:/ { inBlock = 1 }
         inBlock && /url: / {
           sub(/url: ".*"/, "url: \"" urls[++i] "\"")
         }
         /profile:/ { inBlock = 0 }
         { print }
        ' "$BACKUP_FILE" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    echo "- 订阅地址已恢复 >> 新配置中！"
  else
    echo "- 备份文件不存在或为空，无法恢复订阅地址。"
  fi
}

unzip -qo "${ZIPFILE}" -x 'META-INF/*' -d "$MODPATH"
if [ -d /data/adb/box_bll ]; then
  ui_print "- 更新中..."
  ui_print "- ————————————————"
  ui_print "- 正在初始化服务..."
  /data/adb/box_bll/scripts/box.service stop > /dev/null 2>&1
  sleep 1.5
  
  if [ -d /data/adb/box_bll/mihomo ]; then
    mv /data/adb/box_bll/mihomo /data/adb/box_bll/clash
  fi
  if [ -f /data/adb/box_bll/bin/mihomo ]; then
    mv /data/adb/box_bll/bin/mihomo /data/adb/box_bll/bin/clash
  fi

  if [ -d /data/adb/box_bll/clash ]; then
    extract_subscribe_urls
    cp /data/adb/box_bll/clash/config.yaml /data/adb/box_bll/clash/config.yaml.bak
    ui_print "- 配置文件 config.yaml 已备份 bak"
  fi
  if [ -d /data/adb/box_bll/scripts ]; then
    cp /data/adb/box_bll/scripts/box.config /data/adb/box_bll/scripts/box.config.bak
    ui_print "- 用户配置 box.config 已备份 bak"
  fi

  cp -f "$MODPATH/box_bll/clash/config.yaml" /data/adb/box_bll/clash/
  cp -f "$MODPATH/box_bll/clash/Toolbox.sh" /data/adb/box_bll/clash/
  cp -f "$MODPATH/box_bll/scripts/"* /data/adb/box_bll/scripts/
  rm -rf "$MODPATH/box_bll"
  rm -rf /data/adb/box_bll/mihomo
  restore_subscribe_urls
  ui_print "- 正在重启服务..."
  /data/adb/box_bll/scripts/box.service start > /dev/null 2>&1
  ui_print "- 更新完成无需重启设备..."
else
  mv "$MODPATH/box_bll" /data/adb/
  ui_print "- 安装中..."
  ui_print "- ————————————————"
  ui_print "- 安装完成 工作目录"
  ui_print "- data/adb/box_bll/"
  ui_print "- 安装无需重启设备..."
  ui_print "- 首次安装需通过模块开关重启模块服务"
fi

if [ "$KSU" = true ]; then
  sed -i 's/name=Surfingmagisk/name=SurfingKernelSU/g' "$MODPATH/module.prop"
fi

if [ "$APATCH" = true ]; then
  sed -i 's/name=Surfingmagisk/name=SurfingAPatch/g' "$MODPATH/module.prop"
fi

mkdir -p /data/adb/box_bll/bin/
mkdir -p /data/adb/box_bll/run/

rm -f customize.sh
mv -f "$MODPATH/Surfing_service.sh" "$service_dir/"

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm_recursive /data/adb/box_bll/ 0 3005 0755 0644
set_perm_recursive /data/adb/box_bll/scripts/ 0 3005 0755 0700
set_perm_recursive /data/adb/box_bll/bin/ 0 3005 0755 0700
set_perm "$service_dir/Surfing_service.sh" 0 0 0700

chmod ugo+x /data/adb/box_bll/scripts/*

for pid in $(pidof inotifyd); do
  if grep -qE "box.inotify|net.inotify|ctr.inotify" /proc/${pid}/cmdline; then
    kill ${pid}
  fi
done

mkdir -p "$SURFING_PATH"
nohup inotifyd "${SCRIPTS_PATH}box.inotify" "$SURFING_PATH" > /dev/null 2>&1 &
nohup inotifyd "${SCRIPTS_PATH}net.inotify" "$NET_PATH" > /dev/null 2>&1 &
nohup inotifyd "${SCRIPTS_PATH}ctr.inotify" "$CTR_PATH" > /dev/null 2>&1 &
