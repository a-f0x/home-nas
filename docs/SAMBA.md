### Обновить
`sudo apt update`

### Установить самбу
`sudo apt install -y samba samba-common-bin`

### Отредактировать конфиг.
`sudo nano /etc/samba/smb.conf`

### Добавь в конец файла:
```
[share]
    comment = Home NAS Public Share
    path = /mnt/media/volume-a/share
    browseable = yes
    read only = no
    guest ok = yes
    guest only = yes
    create mask = 0775
    directory mask = 0775
    force user = f0x
    force group = f0x
    vfs objects = catia fruit streams_xattr
```
### Перезапустить самбу.
`sudo systemctl restart smbd nmbd`