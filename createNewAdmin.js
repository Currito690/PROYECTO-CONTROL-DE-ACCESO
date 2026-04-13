import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://zurgpxremlrkjzegjpwu.supabase.co';
const supabaseKey = 'sb_publishable_jLDP2IWfn26k96GTWxkdKQ_R0oCtoWk';
const supabase = createClient(supabaseUrl, supabaseKey);

async function createAdmin() {
  const { data, error } = await supabase.auth.signUp({
    email: 'admin@miempresa.com',
    password: 'password123',
    options: {
      data: { name: 'Admin Principal', role: 'Admin' }
    }
  });

  if (error) {
    console.error('Error in signUp:', error.message);
    return;
  }

  if (data.user) {
    const { error: profileError } = await supabase.from('profiles').insert({
      id: data.user.id,
      name: 'Admin Principal',
      role: 'Admin',
      status: 'Active',
      last_access: 'Nunca'
    });
    if (profileError) {
      console.error('Error creating profile:', profileError.message);
    } else {
      console.log('Admin account created successfully: admin@miempresa.com / password123');
    }
  }
}

createAdmin();
