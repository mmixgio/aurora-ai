import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import { Loader2, Sparkles } from "lucide-react";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";

interface TextGeneratorProps {
  onTextGenerated: (text: string) => void;
}

const TextGenerator = ({ onTextGenerated }: TextGeneratorProps) => {
  const [prompt, setPrompt] = useState("");
  const [isGenerating, setIsGenerating] = useState(false);

  const handleGenerate = async () => {
    if (!prompt.trim()) {
      toast.error("Inserisci un prompt");
      return;
    }

    setIsGenerating(true);
    
    try {
      const { data, error } = await supabase.functions.invoke('generate-text', {
        body: { prompt }
      });

      if (error) throw error;

      const generatedText = data?.generatedText || data?.text || "";
      onTextGenerated(generatedText);
      
      // Save to database
      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        await supabase.from('generations').insert({
          user_id: user.id,
          type: 'text',
          prompt,
          result: generatedText
        });
      }
      
      toast.success("Testo generato con successo!");
    } catch (error) {
      console.error('Error generating text:', error);
      toast.error("Errore durante la generazione del testo");
    } finally {
      setIsGenerating(false);
    }
  };

  return (
    <Card className="h-full glass-effect border-border/50 shadow-lg hover:shadow-xl animate-smooth">
      <CardHeader className="pb-4">
        <CardTitle className="flex items-center gap-2 text-2xl">
          <Sparkles className="h-5 w-5 text-primary" />
          Inserisci il tuo prompt
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <Textarea
          placeholder="Scrivi qui cosa vuoi generare..."
          value={prompt}
          onChange={(e) => setPrompt(e.target.value)}
          className="min-h-[300px] resize-none text-base bg-background/50 border-border/50 focus:border-primary animate-smooth rounded-xl"
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
              <Sparkles className="mr-2 h-5 w-5" />
              Genera
            </>
          )}
        </Button>
      </CardContent>
    </Card>
  );
};

export default TextGenerator;