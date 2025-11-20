library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity display_ctrl is
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        mode     : in  std_logic_vector(3 downto 0);
        intento  : in  std_logic_vector(1 downto 0);
        timer    : in  std_logic_vector(5 downto 0);
        an       : out std_logic_vector(3 downto 0);
        seg      : out std_logic_vector(6 downto 0)
    );
end display_ctrl;

architecture rtl of display_ctrl is

    constant MUX_MAX : unsigned(15 downto 0) := to_unsigned(100000, 16);
    signal mux_cnt   : unsigned(15 downto 0) := (others => '0');
    signal mux_sel   : unsigned(1 downto 0) := "00";

    signal d0, d1, d2, d3 : unsigned(3 downto 0);
    signal seg_int : std_logic_vector(6 downto 0);

begin
    seg <= seg_int;

    -- Multiplexing timer
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                mux_cnt <= (others => '0');
                mux_sel <= "00";
            else
                if mux_cnt = MUX_MAX then
                    mux_cnt <= (others => '0');
                    mux_sel <= mux_sel + 1;
                else
                    mux_cnt <= mux_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -- Select data to display
    process(mode, intento, timer)
        variable t : unsigned(5 downto 0);
    begin
        -- Prioridad 1: Si timer > 0, mostrar cuenta regresiva
        if unsigned(timer) > 0 then
            t := unsigned(timer);
            d3 <= to_unsigned(0, 4);
            d2 <= to_unsigned(0, 4);
            d1 <= to_unsigned(to_integer(t) / 10, 4);
            d0 <= to_unsigned(to_integer(t) mod 10, 4);
        else
            -- No hay bloqueo, procesar estados normales
            case mode is
                when "0000" =>   -- Inicio
                    d3 <= "0000"; d2 <= "0000"; d1 <= "0000"; d0 <= "0000";

                when "0001" =>   -- Configuración
                    d3 <= "0000"; d2 <= "0000"; d1 <= "0000"; d0 <= "0001";

                when "0010" =>   -- Clave guardada
                    d3 <= "0000"; d2 <= "0000"; d1 <= "0000"; d0 <= "0010";

                when "0011" =>   -- Modo verificación
                    d3 <= "0000"; d2 <= "0000"; d1 <= "0000"; d0 <= "0011";

                when "1010" =>   -- Letra A (acceso correcto)
                    d3 <= "0000"; d2 <= "0000"; d1 <= "0000"; d0 <= "1010";

                when "1111" =>   -- MOSTRAR INTENTOS RESTANTES
                    d3 <= "1110"; -- E de "Error" o "Err"
                    d2 <= "1110"; -- E
                    d1 <= "1110"; -- E
                    d0 <= resize(unsigned(intento), 4); -- Número de intentos

                when others =>
                    d3 <= "0000"; 
                    d2 <= "0000"; 
                    d1 <= "0000";
                    d0 <= "0000";
            end case;
        end if;
    end process;

    -- Multiplexación de ánodos y selección de dígito
    process(mux_sel, d0, d1, d2, d3)
        variable digit : unsigned(3 downto 0);
    begin
        case mux_sel is
            when "00" => 
                an <= "1110";
                digit := d0;
            when "01" => 
                an <= "1101";
                digit := d1;
            when "10" => 
                an <= "1011";
                digit := d2;
            when "11" => 
                an <= "0111";
                digit := d3;
            when others => 
                an <= "1111";
                digit := d0;
        end case;

        -- Decodificador de 7 segmentos
        case digit is
            when "0000" => seg_int <= "1000000"; -- 0
            when "0001" => seg_int <= "1111001"; -- 1
            when "0010" => seg_int <= "0100100"; -- 2
            when "0011" => seg_int <= "0110000"; -- 3
            when "0100" => seg_int <= "0011001"; -- 4
            when "0101" => seg_int <= "0010010"; -- 5
            when "0110" => seg_int <= "0000010"; -- 6
            when "0111" => seg_int <= "1111000"; -- 7
            when "1000" => seg_int <= "0000000"; -- 8
            when "1001" => seg_int <= "0010000"; -- 9
            when "1010" => seg_int <= "0001000"; -- A
            when "1110" => seg_int <= "0000110"; -- E
            when others => seg_int <= "1111111"; -- apagado
        end case;
    end process;

end rtl;