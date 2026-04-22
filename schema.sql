-- Ejecuta este código en el SQL Editor de Supabase (Dashboard -> SQL Editor -> New Query)

-- 1. Tabla para Ferias/Eventos
CREATE TABLE IF NOT EXISTS ferias (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  location TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  base_hourly_rate NUMERIC DEFAULT 0
);

-- Habilitar RLS en Ferias
ALTER TABLE ferias ENABLE ROW LEVEL SECURITY;
-- Cualquier usuario autenticado puede ver las ferias
CREATE POLICY "Empleados pueden ver ferias" ON ferias FOR SELECT TO authenticated USING (true);
-- Solo los administradores pueden crear, editar y borrar ferias
CREATE POLICY "Admins manage ferias" ON ferias FOR ALL TO authenticated USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'Admin' OR auth.email() = 'macario@duke.com');

-- Datos de prueba para ferias
INSERT INTO ferias (name, start_date, end_date, location) VALUES 
('Feria de Abril (Sevilla)', '2026-04-14', '2026-04-20', 'Recinto Ferial Los Remedios'),
('Feria de Málaga', '2026-08-15', '2026-08-22', 'Cortijo de Torres');

ALTER TABLE IF EXISTS ferias ADD COLUMN IF NOT EXISTS base_hourly_rate NUMERIC DEFAULT 0;

-- 2. Tabla para Registros de Fichaje
CREATE TABLE IF NOT EXISTS time_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  feria_id UUID REFERENCES ferias(id) ON DELETE SET NULL,
  action_type TEXT NOT NULL CHECK (action_type IN ('Entrada', 'Salida')),
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  latitude NUMERIC,
  longitude NUMERIC
);

-- Habilitar RLS en Registros de Fichaje
ALTER TABLE time_logs ENABLE ROW LEVEL SECURITY;
-- Todos pueden ver sus propios registros, los Admin pueden ver todos los registros
DROP POLICY IF EXISTS "Lectura de registros propios" ON time_logs;
CREATE POLICY "Lectura de registros propios" ON time_logs FOR SELECT TO authenticated USING (auth.uid() = user_id OR (SELECT role FROM profiles WHERE id = auth.uid()) = 'Admin');

DROP POLICY IF EXISTS "Insertar registros propios" ON time_logs;
DROP POLICY IF EXISTS "Insertar registros propios o Admin" ON time_logs;
CREATE POLICY "Insertar registros propios o Admin" ON time_logs FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id OR (SELECT role FROM profiles WHERE id = auth.uid()) = 'Admin');

-- 3. Tabla para asignar trabajadores a ferias
CREATE TABLE IF NOT EXISTS feria_workers (
  feria_id UUID REFERENCES ferias(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  PRIMARY KEY (feria_id, user_id)
);

ALTER TABLE feria_workers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin manage feria_workers" ON feria_workers FOR ALL TO authenticated USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'Admin' OR auth.email() = 'macario@duke.com');
CREATE POLICY "Users view assigned ferias" ON feria_workers FOR SELECT TO authenticated USING (user_id = auth.uid() OR (SELECT role FROM profiles WHERE id = auth.uid()) = 'Admin');

-- 4. Precio por hora en profiles + permisos admin para editar fichajes
-- Ejecuta este bloque una sola vez en el SQL Editor de Supabase.
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS hourly_rate NUMERIC DEFAULT 0;

-- Función robusta de detección de admin.
-- Mira el JWT (user_metadata / app_metadata), el email conocido de macario,
-- y por último la tabla profiles. Así coincide con la lógica del frontend
-- y funciona aunque la fila en profiles no esté sincronizada.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    auth.email() = 'macario@duke.com'
    OR LOWER(COALESCE(auth.jwt() -> 'user_metadata' ->> 'role', '')) = 'admin'
    OR LOWER(COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', '')) = 'admin'
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
        AND LOWER(COALESCE(role, '')) = 'admin'
    );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

DROP POLICY IF EXISTS "Admin update any time log" ON time_logs;
CREATE POLICY "Admin update any time log" ON time_logs
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admin delete any time log" ON time_logs;
CREATE POLICY "Admin delete any time log" ON time_logs
  FOR DELETE TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS "Admin update any profile" ON profiles;
CREATE POLICY "Admin update any profile" ON profiles
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Diagnóstico: ejecuta esto para ver tu estado actual:
-- SELECT auth.uid(), auth.email(), (SELECT role FROM profiles WHERE id = auth.uid()) AS my_role, public.is_admin() AS am_i_admin;

-- 5. Rol Manager (ej. Adriana): puede ver horas de todos y fichar en kiosk,
--    pero NO puede editar/eliminar fichajes ni ver tarifas.

-- Función auxiliar para detectar manager
CREATE OR REPLACE FUNCTION public.is_manager()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND LOWER(COALESCE(role, '')) = 'manager'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_manager() TO authenticated;

-- Manager puede ver todos los fichajes (como admin)
DROP POLICY IF EXISTS "Lectura de registros propios" ON time_logs;
CREATE POLICY "Lectura de registros propios" ON time_logs
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR public.is_admin() OR public.is_manager());

-- Manager puede insertar fichajes para cualquier trabajador (kiosk)
DROP POLICY IF EXISTS "Insertar registros propios o Admin" ON time_logs;
CREATE POLICY "Insertar registros propios o Admin" ON time_logs
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id OR public.is_admin() OR public.is_manager());

-- Manager puede ver todos los perfiles (para mostrar directorio de personal)
DROP POLICY IF EXISTS "Manager select all profiles" ON profiles;
CREATE POLICY "Manager select all profiles" ON profiles
  FOR SELECT TO authenticated
  USING (true);

-- Para asignar a ferias, manager puede ver los workers asignados
DROP POLICY IF EXISTS "Users view assigned ferias" ON feria_workers;
CREATE POLICY "Users view assigned ferias" ON feria_workers
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_admin() OR public.is_manager());

-- Asignar rol Manager a Adriana (cambia el email por el suyo real):
-- UPDATE profiles SET role = 'Manager' WHERE email = 'adriana@tudominio.com';

-- 6. Precio por hora personalizado por turno
ALTER TABLE time_logs ADD COLUMN IF NOT EXISTS hourly_rate NUMERIC;

-- 7. Casetas dentro de cada feria
CREATE TABLE IF NOT EXISTS casetas (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  feria_id UUID REFERENCES ferias(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS caseta_workers (
  caseta_id UUID REFERENCES casetas(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  PRIMARY KEY (caseta_id, user_id)
);

ALTER TABLE time_logs ADD COLUMN IF NOT EXISTS caseta_id UUID REFERENCES casetas(id) ON DELETE SET NULL;

ALTER TABLE casetas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Ver casetas" ON casetas;
CREATE POLICY "Ver casetas" ON casetas FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "Admin manage casetas" ON casetas;
CREATE POLICY "Admin manage casetas" ON casetas FOR ALL TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

ALTER TABLE caseta_workers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Ver caseta_workers" ON caseta_workers;
CREATE POLICY "Ver caseta_workers" ON caseta_workers FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_admin() OR public.is_manager());
DROP POLICY IF EXISTS "Admin manage caseta_workers" ON caseta_workers;
CREATE POLICY "Admin manage caseta_workers" ON caseta_workers FOR ALL TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());
