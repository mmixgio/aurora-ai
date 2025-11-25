import { useEffect, useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Button } from "@/components/ui/button";
import { History, Trash2, Image as ImageIcon, FileText } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";

interface Generation {
  id: string;
  type: string;
  prompt: string;
  result: string | null;
  image_url: string | null;
  created_at: string;
}

const GenerationsHistory = () => {
  const [generations, setGenerations] = useState<Generation[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  const loadGenerations = async () => {
    try {
      const { data, error } = await supabase
        .from('generations')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(20);

      if (error) throw error;
      setGenerations(data || []);
    } catch (error) {
      console.error('Error loading generations:', error);
      toast.error("Errore nel caricamento della cronologia");
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadGenerations();

    // Subscribe to realtime updates
    const channel = supabase
      .channel('generations-changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'generations'
        },
        () => {
          loadGenerations();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  const handleDelete = async (id: string) => {
    try {
      const { error } = await supabase
        .from('generations')
        .delete()
        .eq('id', id);

      if (error) throw error;
      toast.success("Generazione eliminata");
    } catch (error) {
      console.error('Error deleting generation:', error);
      toast.error("Errore nell'eliminazione");
    }
  };

  if (isLoading) {
    return (
      <Card className="glass-effect border-border/50">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <History className="h-5 w-5" />
            Cronologia
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-muted-foreground text-sm">Caricamento...</p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="glass-effect border-border/50 shadow-lg hover:shadow-2xl transition-all duration-500 hover:border-primary/30 group h-full">
      <CardHeader className="pb-3 sm:pb-4 space-y-1">
        <CardTitle className="flex items-center gap-2 text-xl sm:text-2xl group-hover:text-primary transition-colors duration-300">
          <div className="p-2 rounded-lg bg-primary/10 group-hover:bg-primary/20 transition-all duration-300 group-hover:scale-110">
            <History className="h-4 w-4 sm:h-5 sm:w-5 text-primary" />
          </div>
          <span className="text-base sm:text-xl">Cronologia ({generations.length})</span>
        </CardTitle>
      </CardHeader>
      <CardContent>
        <ScrollArea className="h-[400px] sm:h-[600px] pr-2 sm:pr-4">
          {generations.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 sm:py-16 text-muted-foreground gap-3">
              <History className="h-12 w-12 sm:h-16 sm:w-16 opacity-20" />
              <p className="text-xs sm:text-sm text-center px-4">
                Nessuna generazione ancora. Inizia a creare!
              </p>
            </div>
          ) : (
            <div className="space-y-2 sm:space-y-3">
              {generations.map((gen) => (
                <div
                  key={gen.id}
                  className="p-3 sm:p-4 rounded-xl border border-border/50 bg-card/50 hover:bg-card hover:border-primary/30 hover:shadow-lg transition-all duration-300 space-y-2 group/item hover:scale-[1.02]"
                >
                  <div className="flex items-start justify-between gap-2">
                    <div className="flex items-center gap-2 flex-1 min-w-0">
                      <div className="p-1.5 rounded-md bg-primary/10 group-hover/item:bg-primary/20 transition-colors duration-300 shrink-0">
                        {gen.type === 'image' ? (
                          <ImageIcon className="h-3 w-3 sm:h-4 sm:w-4 text-primary" />
                        ) : (
                          <FileText className="h-3 w-3 sm:h-4 sm:w-4 text-primary" />
                        )}
                      </div>
                      <p className="text-xs sm:text-sm font-medium truncate">
                        {gen.prompt}
                      </p>
                    </div>
                    <Button
                      variant="ghost"
                      size="icon"
                      onClick={() => handleDelete(gen.id)}
                      className="h-7 w-7 sm:h-8 sm:w-8 shrink-0 hover:text-destructive hover:bg-destructive/10 hover:scale-110 transition-all duration-300"
                    >
                      <Trash2 className="h-3 w-3 sm:h-4 sm:w-4" />
                    </Button>
                  </div>
                  
                  {gen.type === 'image' && gen.image_url && (
                    <div className="relative overflow-hidden rounded-lg group/img">
                      <img
                        src={gen.image_url}
                        alt={gen.prompt}
                        className="w-full rounded-lg border border-border/50 transition-all duration-500 group-hover/img:scale-105"
                      />
                      <div className="absolute inset-0 bg-gradient-to-t from-black/20 to-transparent opacity-0 group-hover/img:opacity-100 transition-opacity duration-300 rounded-lg" />
                    </div>
                  )}
                  
                  {gen.type === 'text' && gen.result && (
                    <p className="text-xs sm:text-sm text-muted-foreground line-clamp-3">
                      {gen.result}
                    </p>
                  )}
                  
                  <p className="text-[10px] sm:text-xs text-muted-foreground/70">
                    {new Date(gen.created_at).toLocaleString('it-IT')}
                  </p>
                </div>
              ))}
            </div>
          )}
        </ScrollArea>
      </CardContent>
    </Card>
  );
};

export default GenerationsHistory;
