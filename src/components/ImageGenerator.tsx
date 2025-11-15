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
    <Card className="h-full glass-effect border-border/50 shadow-lg hover:shadow-xl animate-smooth">
      <CardHeader className="pb-4">
        <CardTitle className="flex items-center gap-2 text-2xl">
          <ImageIcon className="h-5 w-5 text-primary" />
          Genera Immagine
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <Input
          placeholder="Descrivi l'immagine che vuoi creare..."
          value={prompt}
          onChange={(e) => setPrompt(e.target.value)}
          onKeyPress={(e) => e.key === 'Enter' && !isGenerating && handleGenerate()}
          className="h-12 text-base bg-background/50 border-border/50 focus:border-primary animate-smooth rounded-xl"
        />
        
        <Button 
          onClick={handleGenerate} 
          disabled={isGenerating || !prompt.trim()}
          className="w-full rounded-full h-12 text-base font-medium hover:scale-[1.02] active:scale-[0.98] animate-smooth shadow-md"
        >
          {isGenerating ? (
            <>
              <Loader2 className="mr-2 h-5 w-5 animate-spin" />
              Generazione in corso...
            </>
          ) : (
            <>
              <ImageIcon className="mr-2 h-5 w-5" />
              Genera Immagine
            </>
          )}
        </Button>

        {generatedImage && (
          <div className="space-y-3 pt-4 border-t border-border/50 animate-fade-in">
            <img 
              src={generatedImage} 
              alt="Immagine generata" 
              className="w-full rounded-xl shadow-lg border border-border/50"
            />
            <Button 
              onClick={handleDownload}
              variant="outline"
              size="sm"
              className="w-full rounded-full hover:scale-105 animate-smooth"
            >
              <Download className="mr-2 h-4 w-4" />
              Scarica Immagine
            </Button>
          </div>
        )}
      </CardContent>
    </Card>
  );
};

export default ImageGenerator;