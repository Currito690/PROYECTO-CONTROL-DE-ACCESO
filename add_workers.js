import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://zurgpxremlrkjzegjpwu.supabase.co';
const supabaseKey = 'sb_publishable_jLDP2IWfn26k96GTWxkdKQ_R0oCtoWk'; // Using the key from createMacario.js
const supabase = createClient(supabaseUrl, supabaseKey);

const workers = [
  "Ana Jerez", "David", "Bollan", "Carol", "Adriana", "Vero", "Cafelita", 
  "Noelia Algodonales", "Anabel Algar", "Manolo", "Diego", "Yoni", 
  "Angelito", "Lucia Valle", "Primo Julio", "Morales", "Noelia Osorio", "Maria Medina"
];

async function addWorkers() {
  for (const name of workers) {
    const email = name.replace(/ /g, '').toLowerCase() + '@empleado.com';
    const password = 'password123'; // Standard password

    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: { name, role: 'Employee' }
      }
    });

    if (error) {
      console.error(`Error adding user ${name}:`, error.message);
      continue;
    }

    if (data.user) {
      const { error: profileError } = await supabase.from('profiles').upsert({
        id: data.user.id,
        name: name,
        email: email,
        role: 'Employee',
        status: 'Active',
        last_access: 'Nunca'
      });
      
      if (profileError) {
        console.error(`Error creating profile for ${name}:`, profileError.message);
      } else {
        console.log(`Worker ${name} added successfully (Email: ${email}).`);
      }
    }
  }
}

addWorkers();
