library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity key_verify is
    port (
        entered_key : in  std_logic_vector(3 downto 0);  -- clave ingresada con SW en modo verificación
        stored_key  : in  std_logic_vector(3 downto 0);  -- clave almacenada en key_storage
        match       : out std_logic                      -- 1 si coincide, 0 si no
    );
end key_verify;

architecture rtl of key_verify is
begin
    -- Comparación combinacional
    match <= '1' when entered_key = stored_key else '0';
end rtl;
