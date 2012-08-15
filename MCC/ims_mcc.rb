# coding: utf-8

require 'commutation_system'
require 'roo'

print 'Введи номер OFC: '
@ofc_number = gets.chomp! # Номер OFC для которого будем заполнять MCC



# Подключение к IMS Core UGC
@omu_core = CommutationSystem::IMS.new(
  host: '10.52.249.6',
  username: 'admin',
  password: 'lem',
  log: true
)

# Подключение к UMG
@umg = CommutationSystem::UMG.new(
  host: '10.52.251.12',
  username: 'admin',
  password: 'OdiPFblE2s/',
  log: true
)


@omu_core.connection_telnet.connect
@omu_core.connection_telnet.login
@omu_core.connection_telnet.cmd('USE ME:MEID=261;') # Переключаемся на UGC



# Определяем данные OFC
def data_OFC(office_direction_number)
  data_LST_OFC_UGC = @omu_core.connection_telnet.cmd("LST OFC: OFCNO=#{office_direction_number}, OFCTYPE=ALL;")

  office_direction_name_UGC = data_LST_OFC_UGC[:data][/(?<=Office direction name  =  ).+/]
  signaling_type = data_LST_OFC_UGC[:data][/(?<=Signaling type  =  ).+/]
  # Все данные будем сохранять в хэш
  @data_ofc_UGC[:office_direction_number] = office_direction_number
  @data_ofc_UGC[:office_direction_name] = office_direction_name_UGC
  case signaling_type
  when 'Non-BICC/Non-SIP signaling'
    @data_ofc_UGC[:signaling_type] = 'ISUP'
  when 'NGN office'
    @data_ofc_UGC[:signaling_type] = 'SIP'
  end

  bill_office_number = data_LST_OFC_UGC[:data][/(?<=Bill office number  =  ).+/]
  @data_ofc_UGC[:bill_office_number] = bill_office_number

  if @data_ofc_UGC[:signaling_type] == 'ISUP'
    network_indicator =  data_LST_OFC_UGC[:data][/(?<=Network indicator  =  ).+/]
    case network_indicator
    when "National reserved network"
      network_indicator_number = '11'
    when "National network"
      network_indicator_number = '10'
    end

    data_LST_OFI_UGC = @omu_core.connection_telnet.cmd("LST OFI: QR=LOCAL;")
    opc = data_LST_OFI_UGC[:data][/(?<=#{network_indicator} code  =  ).+/].sub(/0+/, '')
    dpc_1 = data_LST_OFC_UGC[:data][/(?<=DPC 1  =  ).+/].sub(/0+/, '')

    @data_ofc_UGC[:network_indicator] = network_indicator
    @data_ofc_UGC[:network_indicator_number] = network_indicator_number
    @data_ofc_UGC[:opc] = opc
    @data_ofc_UGC[:dpc] = dpc_1
  end
end

# Определяем SRT входящие в OFC
def search_SRT
  data_LST_OFC_UGC = @omu_core.connection_telnet.cmd("LST OFC: OFCNO=#{@data_ofc_UGC[:office_direction_number]}, OFCTYPE=ALL, SSR=YES;")

  sub_routes_UGC = []
  if data_LST_OFC_UGC[:data][/(?<=Number of results = )[\d]+(?=[).\n]+---    END)/] == '1'
    sub_routes_UGC << data_LST_OFC_UGC[:data][/(?<=Sub-route name  =  ).+/]
  else
    sub_routes_UGC = data_LST_OFC_UGC[:data].scan(/(?<=^ )[ \w-]+[\w-](?=[ ]{2,}#{@data_ofc_UGC[:office_direction_name]})/)
  end
  @data_ofc_UGC[:sub_routes] = []
  sub_routes_UGC.each { |sub_route| @data_ofc_UGC[:sub_routes] << {sub_route_name: sub_route}}
end

# Определяем данные SRT
def data_SRT


end

def search_TG
  @data_ofc_UGC[:sub_routes].each_with_index do |sub_route, i|

    data_LST_SRT_UGC = @omu_core.connection_telnet.cmd("LST SRT: SRN=\"#{sub_route[:sub_route_name]}\", QR=LOCAL, ST=YES;")

    # Находим номер SRT
    sub_route_number  =  data_LST_SRT_UGC[:data][/(?<=Sub-route number  =  )\d+/]

    trunk_groups_UGC = []
    if data_LST_SRT_UGC[:data][/(?<=Number of results = )[\d]+(?=[).\n]+---    END)/] == '1'
      trunk_groups_UGC << data_LST_SRT_UGC[:data][/(?<=Trunk group name  =  ).+/]
    else
     data_LST_SRT_UGC[:data].scan(/(?<=#{sub_route[:sub_route_name]})[ \w-]+/){|tg| trunk_groups_UGC << tg.sub(/^ +/, '')}
    end
    @data_ofc_UGC[:sub_routes][i][:sub_route_number] = sub_route_number

   @data_ofc_UGC[:sub_routes][i][:trunk_groups] = []
    trunk_groups_UGC.each { |trunk_group| @data_ofc_UGC[:sub_routes][i][:trunk_groups] << {trunk_group_name: trunk_group} if trunk_group}



  end
end

# Определяем данные TG
def data_TG
  @data_ofc_UGC[:sub_routes].each_with_index do |sub_route, i|
    sub_route[:trunk_groups].each_with_index do |tg, j|
      data_LST_TG_UGC = @omu_core.connection_telnet.cmd("LST TG: TGN=\"#{tg[:trunk_group_name]}\", QR=LOCAL;")
      trunk_group_number = data_LST_TG_UGC[:data][/(?<=Trunk group number  =  )\d+/]
      bill_trunk_group_number = data_LST_TG_UGC[:data][/(?<=Bill trunk group number  =  )\d+/]
      circuit_type = data_LST_TG_UGC[:data][/(?<=Circuit type  =  ).+/]
      circuit_type = 'SIP' unless circuit_type
      circuit_selection = data_LST_TG_UGC[:data][/(?<=Circuit selection  =  ).+/]


      @data_ofc_UGC[:sub_routes][i][:trunk_groups][j][:trunk_group_number] = trunk_group_number
      @data_ofc_UGC[:sub_routes][i][:trunk_groups][j][:bill_trunk_group_number] = bill_trunk_group_number
      @data_ofc_UGC[:sub_routes][i][:trunk_groups][j][:circuit_type] = circuit_type
      @data_ofc_UGC[:sub_routes][i][:trunk_groups][j][:circuit_selection] = circuit_selection
    end if sub_route[:trunk_groups]
  end
end

# Поиск каналов в TG
def search_TKC
  @data_ofc_UGC[:ofc_circuit_count] = 0   # Количество каналов в OFC

  @data_ofc_UGC[:sub_routes].each_with_index do |sub_route, i|
    sub_route[:trunk_groups].each_with_index do |tg, j|
      if tg[:circuit_type] == 'ISUP' # Каналы ищем если TG ОКС
        data_LST_N7TKC_UGC = @omu_core.connection_telnet.cmd("LST N7TKC: TGN=\"#{tg[:trunk_group_name]}\", QR=LOCAL;")

        # Каналов может и не быть
        if data_LST_N7TKC_UGC[:data][/No matching result is found/]
          @data_ofc_UGC[:sub_routes][i][:trunk_groups][j][:trunk_circuits] = nil
          break
        end

        @data_ofc_UGC[:sub_routes][i][:trunk_groups][j][:trunk_circuits] = []

        if data_LST_N7TKC_UGC[:data][/(Number of results = 1)/]
          trunk_circuit = [[
            data_LST_N7TKC_UGC[:data][/(?<=MGW name  =  ).+/],
            data_LST_N7TKC_UGC[:data][/(?<=Start CIC  =  )\d+/],
            data_LST_N7TKC_UGC[:data][/(?<=End CIC  =  )\d+/],
            data_LST_N7TKC_UGC[:data][/(?<=Start circuit terminal ID  =  )\d+/],
            data_LST_N7TKC_UGC[:data][/(?<=End circuit terminal ID  =  )\d+/]]]
        else
          trunk_circuit = data_LST_N7TKC_UGC[:data].scan(/(?<=#{tg[:trunk_group_name]}) +NN-MGW01[ \d]+/)
            trunk_circuit.collect! {|w| w.split}
        end

        # Подключаемся к UMG для определения по terminal ID реального расположения потока E1
        @umg.connection_telnet.connect
        @umg.connection_telnet.login

        trunk_circuit.each do |circuit|
          data_LST_TDMTID_start = @umg.connection_telnet.cmd("LST TDMTID: TIDFVDEC=#{circuit[3]};")
          data_LST_TDMTID_end =  @umg.connection_telnet.cmd("LST TDMTID: TIDFVDEC=#{circuit[4]};")
          tid_information_start = data_LST_TDMTID_start[:data][/^[ \d]+[NULL\d]+[ \d]+/].split
          tid_information_end = data_LST_TDMTID_end[:data][/^[ \d]+[NULL\d]+[ \d]+/].split

          @data_ofc_UGC[:sub_routes][i][:trunk_groups][j][:trunk_circuits] <<
          {start_CIC: circuit[1],
           end_CIC: circuit[2],
           start_circuit_terminal_ID: circuit[3],
           end_circuit_terminal_ID: circuit[4],
           start_circuit_E1: tid_information_start[6],
           end_circuit_E1: tid_information_end[6],
           start_circuit_E1_frame: tid_information_start[1],
           start_circuit_E1_slot: tid_information_start[2],
           start_circuit_E1_board: tid_information_start[3],
           start_circuit_E1_port: tid_information_start[5],
           end_circuit_E1_frame: tid_information_end[1],
           end_circuit_E1_slot: tid_information_end[2],
           end_circuit_E1_board: tid_information_end[3],
           end_circuit_E1_port: tid_information_end[5]
          }
          if tid_information_start[6] == '0'
            @data_ofc_UGC[:ofc_circuit_count] += (1..tid_information_end[6].to_i).count
          else
            @data_ofc_UGC[:ofc_circuit_count] += (tid_information_start[6].to_i..tid_information_end[6].to_i).count
          end
        end
      end
    end if sub_route[:trunk_groups]
  end
end

# Находим линк
def search_LNK

  # Нахождение данных о линке ОКС№7
  data_LST_N7DSP_UGC = @omu_core.connection_telnet.cmd("LST N7DSP: DPC=\"#{@data_ofc_UGC[:dpc]}\", SHLINK=TRUE, LTP=LOCAL;")
  linkset_name = data_LST_N7DSP_UGC[:data][/(?<=Linkset name  =  ).+/]
  link_name = data_LST_N7DSP_UGC[:data][/(?<=Link name  =  ).+/]
  data_LST_N7LNK_UGC = @omu_core.connection_telnet.cmd("LST N7LNK: LNKNM=\"#{link_name}\", LTP=LOCAL;")
  m2ua_linkset_name = data_LST_N7LNK_UGC[:data][/(?<=M2UA linkset name  =  ).+/]
  integer_interface_ID = data_LST_N7LNK_UGC[:data][/(?<=Integer interface ID  =  ).+/]

  data_LST_M2LKS_UGC = @omu_core.connection_telnet.cmd("LST M2LKS: LSNM=\"#{m2ua_linkset_name}\", LTP=LOCAL;")
  linkset_number = data_LST_M2LKS_UGC[:data][/(?<=Linkset number  =  )\d+/]

  # Заходим на UMG для определения физического местоположения линка
  data_LST_MTP2LNK_UMG = @umg.connection_telnet.cmd("LST MTP2LNK: LNKTYPE=M2UA64K, LKS=#{linkset_number};")
  link_number_UMG = data_LST_MTP2LNK_UMG[:data][/(?<=^ )\d+(?= +NULL.+#{integer_interface_ID}\n)/]


  data_LST_MTP2LNK_UMG = @umg.connection_telnet.cmd("LST MTP2LNK: LNKNO=#{link_number_UMG}, LNKTYPE=M2UA64K, LKS=#{linkset_number};")
  interface_board_No_UMG = data_LST_MTP2LNK_UMG[:data][/(?<=Interface board No. = )\d+/]
  start_time_slot_UMG = data_LST_MTP2LNK_UMG[:data][/(?<=Start time slot = )\d+/]
  link_E1_UMG = data_LST_MTP2LNK_UMG[:data][/(?<=E1T1 No. = )\d+/]

  data_LST_BRD_UMG = @umg.connection_telnet.cmd("LST BRD: LM=BTBN, BT=E32, BN=#{interface_board_No_UMG};")
  link_frame_UMG = data_LST_BRD_UMG[:data][/(?<=Frame No. = )\d+/]
  link_slot_UMG = data_LST_BRD_UMG[:data][/(?<=Slot No. = )\d+/]

  @data_ofc_UGC[:n7lnk] = {circuit: start_time_slot_UMG, frame: link_frame_UMG, slot: link_slot_UMG, port: link_E1_UMG}
end

# Все данные будем сохранять в хэш
@data_ofc_UGC = {}

data_OFC(@ofc_number)   # Определяем данные OFC
search_SRT              # Находим SRT входящие в OFC
data_SRT                # Определяем данные SRT
search_TG               # Определяем в каждом SRT TG
data_TG                 # Определяем данные TG
search_TKC              # Поиск каналов в TG
search_LNK              # Находим линк

# Определяем тип сигнализации. ОКС или SIP
#ofc_ccs7 if data_LST_OFC_UGC[:data]['Signaling type  =  Non-BICC/Non-SIP signaling']





@umg.connection_telnet.close
@omu_core.connection_telnet.close

p @data_ofc_UGC

File.open("#{@data_ofc_UGC[:office_direction_name]}.txt", "w+") do |file|
  file.puts "Данные OFC"
  file.puts
  file.puts "Название OFC => #{@data_ofc_UGC[:office_direction_name]}"
  file.puts "Номер OFC => #{@data_ofc_UGC[:office_direction_number]}"
  file.puts "Тип сигнализации на OFC => #{@data_ofc_UGC[:signaling_type]}"
  file.puts "Биллинговый номер OFC => #{@data_ofc_UGC[:bill_office_number]}"
  file.puts "Тип сети OFC => #{@data_ofc_UGC[:network_indicator_number]}"
  file.puts "OPC => #{@data_ofc_UGC[:opc]}"
  file.puts "DPC => #{@data_ofc_UGC[:dpc]}"
  file.puts
  @data_ofc_UGC[:sub_routes].each_with_index do |sub_route, i|
    file.puts "Данные SRT"
    file.puts
    file.puts "Название => #{sub_route[:sub_route_name]}"
    file.puts "Номер => #{sub_route[:sub_route_number]}"
    file.puts
    sub_route[:trunk_groups].each_with_index do |tg, j|
      file.puts "Данные TG" if tg[:trunk_circuits]
      file.puts "Название => #{tg[:trunk_group_name]}"
      file.puts "Номер => #{tg[:trunk_group_number]}"
      file.puts "Тип каналов => #{tg[:circuit_type]}"
      file.puts "Выбор каналов => #{tg[:circuit_selection]}"
      file.puts
      tg[:trunk_circuits].each_with_index do |circuit, k|
        file.puts "Данные по каналам"
        file.puts "Начальный CIC => #{circuit[:start_CIC]} Конечный CIC  => #{circuit[:end_CIC]}"
        file.puts "Канал в E1    => #{circuit[:start_circuit_E1]} Канал в E1 => #{circuit[:end_circuit_E1]}"
        file.puts "Полка => #{circuit[:start_circuit_E1_frame]} Слот => #{circuit[:start_circuit_E1_slot]}  Номер потока  => #{circuit[:start_circuit_E1_port]}"
        file.puts
      end if tg[:trunk_circuits]
    end
    file.puts "=" * 30
  end

  file.puts "Данные по линку ОКС"
  file.puts
  file.puts "Канал => #{@data_ofc_UGC[:n7lnk][:circuit]}  Полка => #{@data_ofc_UGC[:n7lnk
  ][:frame]} Слот => #{@data_ofc_UGC[:n7lnk][:slot]} E1 => #{@data_ofc_UGC[:n7lnk][:port]} "
end

