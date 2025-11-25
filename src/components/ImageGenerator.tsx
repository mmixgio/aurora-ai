import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Loader2, ImageIcon, Download } from "lucide-react";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";

interface ImageGeneratorProps {
  onImageGenerated: (imageUrl: string) => void;
}

const ImageGenerator = ({ onImageGenerated }: ImageGeneratorProps) => {
  const [prompt, setPrompt] = useState("");
  const [isGenerating, setIsGenerating] = useState(false);
  const [generatedImage, setGeneratedImage] = useState<string | null>(null);

  const handleGenerate = async () => {
    if (!prompt.trim()) {
      toast.error("Inserisci una descrizione");
      return;
    }

    setIsGenerating(true);
    
    try {
      const { data, error } = await supabase.functions.invoke('generate-image', {
        body: { prompt }
      });

      if (error) throw error;

      if (data?.imageUrl) {
        setGeneratedImage(data.imageUrl);
        onImageGenerated(data.imageUrl);
        
        // Save to database
        const { data: { user } } = await supabase.auth.getUser();
        if (user) {
          await supabase.from('generations').insert({
            user_id: user.id,
            type: 'image',
            prompt,
            image_url: data.imageUrl
          });
        }
        
        toast.success("Immagine generata con successo!");
      } else {
        throw new Error("Nessuna immagine generata");
      }
    } catch (error: any) {
      console.error('Error generating image:', error);
      if (error.message.includes('Rate limit')) {
        toast.error("Limite richieste superato. Riprova tra poco.");
      } else if (error.message.includes('Payment required')) {
        toast.error("Crediti esauriti. Aggiungi crediti al workspace.");
      } else {
        toast.error("Errore durante la generazione dell'immagine");
      }
    } finally {
      setIsGenerating(false);
    }
  };

  const handleDownload = () => {
    if (!generatedImage) return;
    
    const link = document.createElement('a');
    link.href = generatedImage;
    link.download = `aurora-image-${Date.now()}.png`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    toast.success("Download avviato!");
  };

  return (
    <Card className="h-full glass-effect border-border/50 shadow-lg hover:shadow-2xl transition-all duration-500 hover:border-primary/30 group">
      <CardHeader className="pb-3 sm:pb-4 space-y-1">
        <CardTitle className="flex items-center gap-2 text-xl sm:text-2xl group-hover:text-primary transition-colors duration-300">
          <div className="p-2 rounded-lg bg-primary/10 group-hover:bg-primary/20 transition-all duration-300 group-hover:scale-110">
            <ImageIcon className="h-4 w-4 sm:h-5 sm:w-5 text-primary" />
          </div>
          Genera Immagine
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-3 sm:space-y-4">
        <Input
          placeholder="Descrivi l'immagine che vuoi creare..."
          value={prompt}
          onChange={(e) => setPrompt(e.target.value)}
          onKeyPress={(e) => e.key === 'Enter' && !isGenerating && handleGenerate()}
          className="h-11 sm:h-12 text-sm sm:text-base bg-background/50 border-border/50 focus:border-primary focus:ring-2 focus:ring-primary/20 transition-all duration-300 rounded-xl hover:bg-background/70"
        />
        
        <Button 
          onClick={handleGenerate} 
          disabled={isGenerating || !prompt.trim()}
          className="w-full rounded-full h-11 sm:h-12 text-sm sm:text-base font-medium hover:scale-105 active:scale-95 transition-all duration-300 shadow-md hover:shadow-xl disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100"
        >
          {isGenerating ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 sm:h-5 sm:w-5 animate-spin" />
              Generazione in corso...
            </>
          ) : (
            <>
              <ImageIcon className="mr-2 h-4 w-4 sm:h-5 sm:w-5 group-hover:rotate-12 transition-transform duration-300" />
              Genera Immagine
            </>
          )}
        </Button>

        {generatedImage && (
          <div className="space-y-3 pt-4 border-t border-border/50 animate-fade-in">
            <div className="relative overflow-hidden rounded-xl group/img">
              <img 
                src={generatedImage} 
                alt="Immagine generata" 
                className="w-full rounded-xl shadow-lg border border-border/50 transition-all duration-500 group-hover/img:scale-105 group-hover/img:shadow-2xl"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-black/30 to-transparent opacity-0 group-hover/img:opacity-100 transition-opacity duration-300 rounded-xl" />
            </div>
            <Button 
              onClick={handleDownload}
              variant="outline"
              size="sm"
              className="w-full rounded-full hover:scale-105 active:scale-95 transition-all duration-300 hover:bg-primary hover:text-primary-foreground"
            >
              <Download className="mr-2 h-3 w-3 sm:h-4 sm:w-4" />
              Scarica Immagine
            </Button>
          </div>
        )}
      </CardContent>
    </Card>
  );
};

export default ImageGenerator;