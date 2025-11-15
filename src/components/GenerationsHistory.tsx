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
    <Card className="glass-effect border-border/50">
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <History className="h-5 w-5" />
          Cronologia ({generations.length})
        </CardTitle>
      </CardHeader>
      <CardContent>
        <ScrollArea className="h-[600px] pr-4">
          {generations.length === 0 ? (
            <p className="text-muted-foreground text-sm text-center py-8">
              Nessuna generazione ancora. Inizia a creare!
            </p>
          ) : (
            <div className="space-y-3">
              {generations.map((gen) => (
                <div
                  key={gen.id}
                  className="p-4 rounded-lg border border-border/50 bg-card/50 hover:bg-card animate-smooth space-y-2"
                >
                  <div className="flex items-start justify-between gap-2">
                    <div className="flex items-center gap-2 flex-1 min-w-0">
                      {gen.type === 'image' ? (
                        <ImageIcon className="h-4 w-4 text-primary shrink-0" />
                      ) : (
                        <FileText className="h-4 w-4 text-primary shrink-0" />
                      )}
                      <p className="text-sm font-medium truncate">
                        {gen.prompt}
                      </p>
                    </div>
                    <Button
                      variant="ghost"
                      size="icon"
                      onClick={() => handleDelete(gen.id)}
                      className="h-8 w-8 shrink-0 hover:text-destructive"
                    >
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  </div>
                  
                  {gen.type === 'image' && gen.image_url && (
                    <img
                      src={gen.image_url}
                      alt={gen.prompt}
                      className="w-full rounded-lg border border-border/50"
                    />
                  )}
                  
                  {gen.type === 'text' && gen.result && (
                    <p className="text-sm text-muted-foreground line-clamp-3">
                      {gen.result}
                    </p>
                  )}
                  
                  <p className="text-xs text-muted-foreground">
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
