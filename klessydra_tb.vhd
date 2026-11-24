library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity klessydra_tb is
end entity;

architecture sim of klessydra_tb is
  constant CLK_PERIOD : time := 10 ns;
  constant RAM_WORDS  : natural := 16384; -- 64 KB

  signal clk_i          : std_logic := '0';
  signal clock_en_i     : std_logic := '1';
  signal rst_ni         : std_logic := '0';
  signal test_en_i      : std_logic := '0';
  signal boot_addr_i    : std_logic_vector(31 downto 0) := X"00000000";
  signal core_id_i      : std_logic_vector(3 downto 0) := "0000";
  signal cluster_id_i   : std_logic_vector(5 downto 0) := "000000";

  signal instr_req_o    : std_logic;
  signal instr_gnt_i    : std_logic := '0';
  signal instr_rvalid_i : std_logic := '0';
  signal instr_addr_o   : std_logic_vector(31 downto 0);
  signal instr_rdata_i  : std_logic_vector(31 downto 0) := (others => '0');

  signal data_req_o     : std_logic;
  signal data_gnt_i     : std_logic := '0';
  signal data_rvalid_i  : std_logic := '0';
  signal data_we_o      : std_logic;
  signal data_be_o      : std_logic_vector(3 downto 0);
  signal data_addr_o    : std_logic_vector(31 downto 0);
  signal data_wdata_o   : std_logic_vector(31 downto 0);
  signal data_rdata_i   : std_logic_vector(31 downto 0) := (others => '0');
  signal data_err_i     : std_logic := '0';

  signal irq_i          : std_logic := '0';
  signal irq_id_i       : std_logic_vector(4 downto 0) := (others => '0');
  signal irq_ack_o      : std_logic;
  signal irq_id_o       : std_logic_vector(4 downto 0);
  signal irq_sec_i      : std_logic := '0';
  signal sec_lvl_o      : std_logic;

  signal debug_req_i    : std_logic := '0';
  signal debug_gnt_o    : std_logic;
  signal debug_rvalid_o : std_logic;
  signal debug_addr_i   : std_logic_vector(14 downto 0) := (others => '0');
  signal debug_we_i     : std_logic := '0';
  signal debug_wdata_i  : std_logic_vector(31 downto 0) := (others => '0');
  signal debug_rdata_o  : std_logic_vector(31 downto 0);
  signal debug_halted_o : std_logic;
  signal debug_halt_i   : std_logic := '0';
  signal debug_resume_i : std_logic := '0';

  signal fetch_enable_i : std_logic := '0';
  signal core_busy_o    : std_logic;
  signal ext_perf_counters_i : std_logic_vector(0 to 1) := (others => '0');

  type ram_t is array (0 to RAM_WORDS - 1) of std_logic_vector(31 downto 0);
  signal ram : ram_t := (
    32 => x"f14022f3",
    33 => x"08029c63",
    34 => x"00008137",
    35 => x"ff010113",
    36 => x"00a00293",
    37 => x"01400313",
    38 => x"006283b3",
    39 => x"01e00e13",
    40 => x"09c39063",
    41 => x"405303b3",
    42 => x"00a00e13",
    43 => x"09c39263",
    44 => x"0062c3b3",
    45 => x"01e00e13",
    46 => x"09c39463",
    47 => x"02628eb3",
    48 => x"0c800e13",
    49 => x"09ce9663",
    50 => x"00004537",
    51 => x"01d52023",
    52 => x"00052f03",
    53 => x"09df1663",
    54 => x"00000413",
    55 => x"06400493",
    56 => x"00000913",
    57 => x"025909b3",
    58 => x"01340433",
    59 => x"00852223",
    60 => x"00452a03",
    61 => x"00190913",
    62 => x"fe9946e3",
    63 => x"200005b7",
    64 => x"17000613",
    65 => x"00064683",
    66 => x"00068863",
    67 => x"00d58023",
    68 => x"00160613",
    69 => x"ff1ff06f",
    70 => x"0005a223",
    71 => x"0000006f",
    72 => x"200005b7",
    73 => x"01100713",
    74 => x"00e5a223",
    75 => x"0000006f",
    76 => x"200005b7",
    77 => x"01200713",
    78 => x"00e5a223",
    79 => x"0000006f",
    80 => x"200005b7",
    81 => x"01300713",
    82 => x"00e5a223",
    83 => x"0000006f",
    84 => x"200005b7",
    85 => x"02100713",
    86 => x"00e5a223",
    87 => x"0000006f",
    88 => x"200005b7",
    89 => x"03100713",
    90 => x"00e5a223",
    91 => x"0000006f",
    92 => x"73656c4b",
    93 => x"72647973",
    94 => x"20542d61",
    95 => x"65726f43",
    96 => x"6b72614d",
    97 => x"7268442f",
    98 => x"6f747379",
    99 => x"5220656e",
    100 => x"49323356",
    101 => x"6542204d",
    102 => x"6d68636e",
    103 => x"206b7261",
    104 => x"000a4b4f",
    others => (others => '0')
  );


  signal cycle_count       : integer := 0;
  signal instruction_count : integer := 0;
  signal halt_sim          : boolean := false;

begin
  -- Combinational grant signals
  instr_gnt_i <= instr_req_o;
  data_gnt_i  <= data_req_o;

  -- Clock generation
  clk_process: process
  begin
    while not halt_sim loop
      clk_i <= '0';
      wait for CLK_PERIOD / 2;
      clk_i <= '1';
      wait for CLK_PERIOD / 2;
    end loop;
    wait;
  end process;

  -- Reset process
  reset_proc: process
  begin
    rst_ni <= '0';
    fetch_enable_i <= '0';
    wait for 50 ns;
    rst_ni <= '1';
    wait for 20 ns;
    fetch_enable_i <= '1';
    wait;
  end process;

  -- Memory responder and simulation monitor
  mem_proc: process(clk_i)
    variable i_idx : integer;
    variable d_idx : integer;
    variable l     : line;
    variable c     : character;
  begin
    if rising_edge(clk_i) then
      if rst_ni = '0' then
        instr_rvalid_i <= '0';
        data_rvalid_i  <= '0';
        cycle_count    <= 0;
        instruction_count <= 0;
      else
        cycle_count <= cycle_count + 1;

        if (cycle_count mod 10000 = 0) then
          report "Cycle: " & integer'image(cycle_count) & " Instructions: " & integer'image(instruction_count);
        end if;

        -- Instruction memory responder (PULP protocol: 1 cycle read latency)
        instr_rvalid_i <= instr_req_o;
        if instr_req_o = '1' then
          i_idx := to_integer(unsigned(instr_addr_o(15 downto 2)));
          if i_idx < RAM_WORDS then
            instr_rdata_i <= ram(i_idx);
          else
            instr_rdata_i <= (others => '0');
          end if;
          instruction_count <= instruction_count + 1;
        end if;

        -- Data memory responder
        data_rvalid_i <= data_req_o;
        if data_req_o = '1' then
          d_idx := to_integer(unsigned(data_addr_o(15 downto 2)));
          if data_we_o = '1' then
            -- MMIO write checks
            if data_addr_o = X"20000000" then
              c := character'val(to_integer(unsigned(data_wdata_o(7 downto 0))));
              report "UART OUT: " & c;
              write(l, c);
              writeline(output, l);
            elsif data_addr_o = X"20000004" then
              report "TOHOST exit requested: " & integer'image(to_integer(unsigned(data_wdata_o)));
              report "Klessydra-T simulation finished successfully!";
              report "Total execution cycles: " & integer'image(cycle_count);
              report "Total instructions executed: " & integer'image(instruction_count);
              halt_sim <= true;
            elsif d_idx < RAM_WORDS then
              if data_be_o(0) = '1' then ram(d_idx)(7 downto 0)   <= data_wdata_o(7 downto 0); end if;
              if data_be_o(1) = '1' then ram(d_idx)(15 downto 8)  <= data_wdata_o(15 downto 8); end if;
              if data_be_o(2) = '1' then ram(d_idx)(23 downto 16) <= data_wdata_o(23 downto 16); end if;
              if data_be_o(3) = '1' then ram(d_idx)(31 downto 24) <= data_wdata_o(31 downto 24); end if;
            end if;
          else
            if d_idx < RAM_WORDS then
              data_rdata_i <= ram(d_idx);
            else
              data_rdata_i <= (others => '0');
            end if;
          end if;
        end if;

      end if;
    end if;
  end process;

  -- Core instantiation
  dut: entity work.klessydra_t1_3th_core
    generic map (
      THREAD_POOL_SIZE      => 3,
      LUTRAM_RF             => 1,
      RV32E                 => 0,
      RV32M                 => 1,
      superscalar_exec_en   => 1,
      accl_en               => 1,
      replicate_accl_en     => 0,
      multithreaded_accl_en => 0,
      SPM_NUM               => 4,
      Addr_Width            => 14,
      SIMD                  => 1,
      MCYCLE_EN             => 0,
      MINSTRET_EN           => 0,
      MHPMCOUNTER_EN        => 0,
      count_all             => 1,
      debug_en              => 0,
      tracer_en             => 1
    )
    port map (
      clk_i               => clk_i,
      clock_en_i          => clock_en_i,
      rst_ni              => rst_ni,
      test_en_i           => test_en_i,
      boot_addr_i         => boot_addr_i,
      core_id_i           => core_id_i,
      cluster_id_i        => cluster_id_i,
      instr_req_o         => instr_req_o,
      instr_gnt_i         => instr_gnt_i,
      instr_rvalid_i      => instr_rvalid_i,
      instr_addr_o        => instr_addr_o,
      instr_rdata_i       => instr_rdata_i,
      data_req_o          => data_req_o,
      data_gnt_i          => data_gnt_i,
      data_rvalid_i       => data_rvalid_i,
      data_we_o           => data_we_o,
      data_be_o           => data_be_o,
      data_addr_o         => data_addr_o,
      data_wdata_o        => data_wdata_o,
      data_rdata_i        => data_rdata_i,
      data_err_i          => data_err_i,
      irq_i               => irq_i,
      irq_id_i            => irq_id_i,
      irq_ack_o           => irq_ack_o,
      irq_id_o            => irq_id_o,
      irq_sec_i           => irq_sec_i,
      sec_lvl_o           => sec_lvl_o,
      debug_req_i         => debug_req_i,
      debug_gnt_o         => debug_gnt_o,
      debug_rvalid_o      => debug_rvalid_o,
      debug_addr_i        => debug_addr_i,
      debug_we_i          => debug_we_i,
      debug_wdata_i       => debug_wdata_i,
      debug_rdata_o       => debug_rdata_o,
      debug_halted_o      => debug_halted_o,
      debug_halt_i        => debug_halt_i,
      debug_resume_i      => debug_resume_i,
      fetch_enable_i      => fetch_enable_i,
      core_busy_o         => core_busy_o,
      ext_perf_counters_i => ext_perf_counters_i(0 to 1)
    );

end architecture;
