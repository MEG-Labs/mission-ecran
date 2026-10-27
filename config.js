// Configuration de Mission Écran.
// Laisse SUPABASE_URL vide pour essayer l'app en MODE DÉMO (données gardées sur l'appareil seulement).
window.APP_CONFIG = {
  // Supabase > Project Settings > API
  SUPABASE_URL: "",        // ex. "https://abcdxyz.supabase.co"
  SUPABASE_ANON_KEY: "",   // clé "anon public"

  // Notifications push via l'app ntfy (Android, gratuite)
  NTFY_SERVER: "https://ntfy.sh",
  NTFY_TOPIC: "",          // choisis un nom long et difficile à deviner, ex. "mission-ecran-7f3k9q2xw8"

  // Nom affiché aux enfants pendant l'attente ("En attente de papa…")
  PARENT_LABEL: "papa ou maman"
};
