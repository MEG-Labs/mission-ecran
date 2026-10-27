// Configuration de Mission Écran.
// Laisse SUPABASE_URL vide pour essayer l'app en MODE DÉMO (données gardées sur l'appareil seulement).
// L'URL et la clé "anon" ne donnent accès à rien sans connexion : toutes les données sont protégées
// par les règles de sécurité de schema.sql. Le sujet ntfy, lui, est gardé dans Supabase (jamais ici).
window.APP_CONFIG = {
  SUPABASE_URL: "",        // Supabase > Project Settings > API > Project URL
  SUPABASE_ANON_KEY: "",   // Supabase > Project Settings > API > clé "anon public"
  PARENT_LABEL: "papa ou maman"
};
