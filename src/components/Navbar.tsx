import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Sparkles, LogOut, User } from "lucide-react";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";
import type { User as SupabaseUser, Session } from "@supabase/supabase-js";

const Navbar = () => {
  const navigate = useNavigate();
  const [user, setUser] = useState<SupabaseUser | null>(null);
  const [session, setSession] = useState<Session | null>(null);

  useEffect(() => {
    // Set up auth state listener FIRST
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (event, session) => {
        setSession(session);
        setUser(session?.user ?? null);
      }
    );

    // THEN check for existing session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      setUser(session?.user ?? null);
    });

    return () => subscription.unsubscribe();
  }, []);

  const handleLogout = async () => {
    try {
      const { error } = await supabase.auth.signOut();
      if (error) throw error;
      toast.success("Logout effettuato!");
      navigate("/auth");
    } catch (error: any) {
      toast.error("Errore durante il logout");
    }
  };

  return (
    <nav className="border-b border-border bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 sticky top-0 z-50">
      <div className="container flex h-16 items-center px-8">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-primary to-primary-hover shadow-md">
            <Sparkles className="h-5 w-5 text-primary-foreground" />
          </div>
          <span className="text-xl font-semibold tracking-tight text-foreground">Aurora</span>
        </div>
        
        <div className="ml-auto flex items-center gap-4">
          <span className="text-sm text-muted-foreground font-medium hidden sm:block">
            AI Creative Workspace
          </span>
          
          {user ? (
            <div className="flex items-center gap-3">
              <div className="flex items-center gap-2 text-sm text-muted-foreground">
                <User className="h-4 w-4" />
                <span className="hidden sm:inline">{user.email}</span>
              </div>
              <Button
                onClick={handleLogout}
                variant="outline"
                size="sm"
                className="border-border/50 hover:bg-secondary"
              >
                <LogOut className="h-4 w-4 sm:mr-2" />
                <span className="hidden sm:inline">Logout</span>
              </Button>
            </div>
          ) : (
            <Button
              onClick={() => navigate("/auth")}
              className="bg-primary hover:bg-primary-hover text-primary-foreground"
              size="sm"
            >
              <User className="h-4 w-4 sm:mr-2" />
              <span className="hidden sm:inline">Accedi</span>
            </Button>
          )}
        </div>
      </div>
    </nav>
  );
};

export default Navbar;