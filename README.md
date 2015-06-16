# netsetup
Утилита настройки клиентских сетевых интерфейсов для FreeBSD.

---------------------------------------------------------------------------------
<b>КОФНИГУРАЦИОННЫЙ ФАЙЛ ПРОГРАММЫ:</b>

По-умолчанию /etc/netsetup.conf. Может быть переопредлен при вызове программы (см. -h).

Параметры:
CONFIG_DIR - директория в системе, в которой хранятся конфигурационный файлы сети.
	По-умолчанию /etc/netsetup/
TMP_DIR - директория в системе, в которой будут храниться временные файлы. Принципиально,
	чтобы эта директория находилась в /tmp.
	По-умолчанию /tmp/netsetup/
FILES - список файлов, составлюящих конфигурационный сет. Перечисление через запятую.
	По-умолчанию SWITCHES.conf,AP_LINK.conf,RESOURCES.conf
MAX_VLANS - максимальное количество vlan. По-умолчанию 4026
MAX_PORTS - максимальное количество портов в одном коммутаторе. По-умолчанию 48
SW_GROUP - список групп, в которые будут добавлены MGMT интерфейсы коммутаторов. По-умолчанию CoNet

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
<b>КОНФИГУРАЦИОННЫЕ ФАЙЛЫ СЕТИ:</b>

В конфигуркционных файлах комментарием считается строка, которая начинается с #.
Строка в конфигурационном файле будет воспринята программой только при соответствии формату (порядок опций важен)

Есть три типа записей в конфигурационных файлах:

1. Описание коммутатора.

Формат: SW <name> parent <parent netif> base <base_vlan> inet <gateway ip with bitmask> count <port_count> ignore <ignored_ports>"

Параметр ignore является необязательным.

Пример:

SW TEST-SW parent rm0 base 100 inet 192.168.1.1/30 count 8 ignore 1,2<br>
SW TEST-SW parent rm0 base 100 inet 192.168.1.1/30 count 8

2. Описание связи точки подключения с портом коммутатора.

Формат: AP_LINK <ap name> dev <device_name> port <port name>

Пример:

AP_LINK IVANOV-II dev TEST-SW port 3<br>
AP_LINK SYDOROV-SS dev ROUTER port re0


3. Описание ресурсов точки подключения.

Формат:

RES <ap_name> group <group name> inet <gateway ip with bitmask> lan <x.x.x.x/x-x.x.x>

Все параметры, кроме ap_name являются необязательными.
Все параметры, кроме ap_name, могут быть записаны через запятую. Напрмиер, group group1,group2.

Пример:

RES IVANOV-II group Group1 inet 192.168.0.1/30 lan 10.0.0.0/24-192.168.0.2<br>
RES IVANOV-II group Cgroup2<br>
RES SYDOROV-SS inet 192.1680.0.4/30


Программа не запрещает того, чтобы описание SW было не в файле SWITCHES.conf, а в любом другом, входящем в конфигурационный набор.
Но, все же, стоит избегать такой практики.

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
<b>ЛОГИРОВАНИЕ:</b>

Программа поддерживает 3 уровня вывода отладочной информации, определяемых опцией -d 1|2|3.

Логгирование ведется в /tmp/log/netsetup/




