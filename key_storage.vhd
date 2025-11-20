library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity key_storage is
    port (
        clk        : in  std_logic;
        reset      : in  std_logic;  -- reset síncrono desde BTNR
        load_key   : in  std_logic;  -- 1 pulso desde BTNC (solo en modo configuración)
        sw_key     : in  std_logic_vector(3 downto 0);
        stored_key : out std_logic_vector(3 downto 0)
    );
end key_storage;

architecture rtl of key_storage is
    signal reg_key : std_logic_vector(3 downto 0);
begin

    stored_key <= reg_key;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                reg_key <= (others => '0');      -- al inicio la clave es 0000
            else
                if load_key = '1' then
                    reg_key <= sw_key;           -- carga la clave desde los switches
                end if;
            end if;
        end if;
    end process;

end rtl;
