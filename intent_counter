library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity intent_counter is
    port (
        clk   : in  std_logic;
        reset : in  std_logic;                     -- reset síncrono (BTNR)
        fail  : in  std_logic;                     -- pulso de un fallo en verificación
        clear : in  std_logic;                     -- reinicia los intentos a 3
        count : out std_logic_vector(1 downto 0)   -- valores: 3,2,1,0
    );
end intent_counter;

architecture rtl of intent_counter is
    signal attempts : unsigned(1 downto 0) := "11";  -- 3 intentos
begin

    count <= std_logic_vector(attempts);

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                attempts <= "11";                  -- 3 intentos
            else

                if clear = '1' then
                    attempts <= "11";              -- reinicio desde el TOP
                elsif fail = '1' then
                    -- Decrementar solo si aún no está en 0
                    if attempts > 0 then
                        attempts <= attempts - 1;
                    end if;
                end if;

            end if;
        end if;
    end process;

end rtl;
