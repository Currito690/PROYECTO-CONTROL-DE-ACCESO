import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://zurgpxremlrkjzegjpwu.supabase.co';
const supabaseKey = 'sb_publishable_jLDP2IWfn26k96GTWxkdKQ_R0oCtoWk';
const supabase = createClient(supabaseUrl, supabaseKey);

const feriasData = [
  { name: "Feria de Vejer de la frontera", location: "Vejer de la frontera", start_date: "2026-04-10", end_date: "2026-04-14" },
  { name: "Feria de Rota", location: "Rota", start_date: "2026-05-01", end_date: "2026-05-05" },
  { name: "Feria de Jerez", location: "Jerez", start_date: "2026-05-02", end_date: "2026-05-09" },
  { name: "Feria de San Jose Del Valle", location: "San Jose Del Valle", start_date: "2026-05-27", end_date: "2026-05-31" },
  { name: "Feria de Paterna", location: "Paterna", start_date: "2026-06-05", end_date: "2026-06-09" },
  { name: "Feria de Torrecera", location: "Torrecera", start_date: "2026-06-12", end_date: "2026-06-16" },
  { name: "Feria de Revilla", location: "Revilla", start_date: "2026-06-25", end_date: "2026-06-29" },
  { name: "Feria de Benalup", location: "Benalup", start_date: "2026-07-23", end_date: "2026-07-27" },
  { name: "Doma Vaquera Alcala", location: "Alcala", start_date: "2026-08-01", end_date: "2026-08-05" },
  { name: "Feria de la Barca", location: "La Barca", start_date: "2026-08-05", end_date: "2026-08-09" },
  { name: "Feria de Estella", location: "Estella", start_date: "2026-08-12", end_date: "2026-08-16" },
  { name: "Feria de Alcala", location: "Alcala", start_date: "2026-08-27", end_date: "2026-08-30" },
  { name: "Feria de Guadalcacin", location: "Guadalcacin", start_date: "2026-09-02", end_date: "2026-09-06" },
  { name: "Feria de Tarifa", location: "Tarifa", start_date: "2026-09-06", end_date: "2026-09-13" },
  { name: "Feria de Villamartin", location: "Villamartin", start_date: "2026-09-19", end_date: "2026-09-23" },
  { name: "Feria de Arcos", location: "Arcos", start_date: "2026-09-25", end_date: "2026-09-29" }
];

async function createFerias() {
  const { error: authError } = await supabase.auth.signInWithPassword({
    email: 'macario@duke.com',
    password: 'master'
  });

  if (authError) {
    console.error("Error logging in:", authError.message);
    return;
  }

  const { data, error } = await supabase.from('ferias').insert(feriasData);

  if (error) {
    console.error("Error al insertar ferias:", error.message);
  } else {
    console.log("¡Todas las ferias se insertaron correctamente en el orden estipulado con fechas aproximadas de 2026!");
  }
}

createFerias();
