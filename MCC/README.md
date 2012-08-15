Программа предназдначена для создания файла МСС.

Возможные ошибки:
1. При определении данных линка учитывалась ситуация только с одним линком. С большим кол-вом нужно дорабатывать программу.


Алгоритм работы:
1. Пользователь задаёт номер OFC.
2. Команда "LST OFC: OFCNO=0, OFCTYPE=ALL, SSR=YES;"
  2.1. Определяем название OFC.
  2.2. Определяем тип сигнализации. Анализируем параметр "Signaling type".
  2.3. Определяем SRT.
  2.4. Определяем OPC и DPC.
3. Команда "LST SRT: SRN="NN-ATE225-SRT01", QR=LOCAL, ST=YES;"
  3.2. Определяем номер SRT 
  3.1. Определяем все TG которые принадлежат OFC
4. Команда "LST TG: TGN="NN-ATE225-N7TG01", QR=LOCAL;"
  4.1. Определяем номер TG
  4.2. Определяем тип каналов 
  4.3. Тип выбора каналов
5. Команда "LST N7TKC: TGN="NN-ATE225-N7TG02", QR=LOCAL;"
  5.1. Находим каналы принадлежащие этой TG
6. Команда "LST TDMTID: TIDFVDEC=209;". Команда дается на UMG.
  6.1. Определяем по TID реальный канал в потоке E1.
7. Команда "LST N7DSP: DPC="f", SHLINK=TRUE, LTP=LOCAL;"
  7.1. Определяем название линка
8. Команда "LST N7LNK: LNKNM="NN-NSS-N7LNK01", LTP=LOCAL;"
  8.1. Определяем обозначение линка, он аналогичен на UMG
  8.2. Определяем название MTP2 линка
9. Команда "LST M2LKS: LSNM="NN-MGW01-M2UALKS00", LTP=LOCAL;"
  9.1. Определяем номер MTP2 линка, он аналогичен на UMG
10. Команда "LST MTP2LNK: LNKTYPE=M2UA64K, LKS=0;". Команда дается на UMG.
  10.1. Определяем номер линка 
11. Команда "LST MTP2LNK: LNKTYPE=M2UA64K, LKS=0;". Команда дается на UMG. 
  11.1. Определяем номер канала с линком
  11.2. Определяем логический номер E1
12. Команда "LST BRD: LM=BTBN, BT=E32, BN=0;". Команда дается на UMG.
  12.1. Определяем реальные данные потока. Полка, слот, номер потока.
