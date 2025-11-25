import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { ScrollArea } from "@/components/ui/scroll-area";
import { History, Trash2, Image as ImageIcon, FileText, X } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";

interface Generation {
  id: string;
  type: string;
  prompt: string;
  result: string | null;
  image_url: string | null;
  created_at: string;
}

interface HistorySidebarProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

const HistorySidebar = ({ open, onOpenChange }: HistorySidebarProps) => {
  const [generations, setGenerations] = useState<Generation[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  const loadGenerations = async () => {
    try {
      const { data, error } = await supabase
        .from('generations')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(50);

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
    if (open) {
      loadGenerations();
    }

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
  }, [open]);

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

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent 
        side="left" 
        className="w-full sm:w-[400px] lg:w-[33vw] p-0 border-r border-border/50 bg-background/95 backdrop-blur-lg"
      >
        <SheetHeader className="px-6 py-4 border-b border-border/50">
          <SheetTitle className="flex items-center gap-3 text-xl">
            <div className="p-2 rounded-lg bg-primary/10">
              <History className="h-5 w-5 text-primary" />
            </div>
            <span>Cronologia</span>
            <span className="ml-auto text-sm text-muted-foreground font-normal">
              {generations.length} {generations.length === 1 ? 'elemento' : 'elementi'}
            </span>
          </SheetTitle>
        </SheetHeader>

        <ScrollArea className="h-[calc(100vh-80px)] px-4 py-4">
          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
            </div>
          ) : generations.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-16 px-4 text-center">
              <div className="p-4 rounded-full bg-muted/50 mb-4">
                <History className="h-12 w-12 text-muted-foreground/30" />
              </div>
              <p className="text-sm text-muted-foreground">
                Nessuna generazione ancora.
              </p>
              <p className="text-xs text-muted-foreground/70 mt-1">
                Inizia a creare per vedere la cronologia!
              </p>
            </div>
          ) : (
            <div className="space-y-2">
              {generations.map((gen) => (
                <div
                  key={gen.id}
                  className="group p-4 rounded-xl border border-border/50 bg-card/50 hover:bg-card hover:border-primary/30 hover:shadow-md transition-all duration-300 space-y-3"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex items-start gap-3 flex-1 min-w-0">
                      <div className="p-2 rounded-lg bg-primary/10 group-hover:bg-primary/20 transition-colors duration-300 shrink-0">
                        {gen.type === 'image' ? (
                          <ImageIcon className="h-4 w-4 text-primary" />
                        ) : (
                          <FileText className="h-4 w-4 text-primary" />
                        )}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium line-clamp-2 mb-1">
                          {gen.prompt}
                        </p>
                        <p className="text-xs text-muted-foreground/70">
                          {new Date(gen.created_at).toLocaleString('it-IT', {
                            day: '2-digit',
                            month: 'short',
                            year: 'numeric',
                            hour: '2-digit',
                            minute: '2-digit'
                          })}
                        </p>
                      </div>
                    </div>
                    <Button
                      variant="ghost"
                      size="icon"
                      onClick={() => handleDelete(gen.id)}
                      className="h-8 w-8 shrink-0 opacity-0 group-hover:opacity-100 hover:text-destructive hover:bg-destructive/10 transition-all duration-300"
                    >
                      <Trash2 className="h-4 w-4" />
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
                    <div className="p-3 rounded-lg bg-muted/30 border border-border/30">
                      <p className="text-xs text-muted-foreground line-clamp-3 leading-relaxed">
                        {gen.result}
                      </p>
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </ScrollArea>
      </SheetContent>
    </Sheet>
  );
};

export default HistorySidebar;
