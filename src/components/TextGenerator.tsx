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
    <Card className="h-full glass-effect border-border/50 shadow-lg hover:shadow-2xl transition-all duration-500 hover:border-primary/30 group">
      <CardHeader className="pb-3 sm:pb-4 space-y-1">
        <CardTitle className="flex items-center gap-2 text-xl sm:text-2xl group-hover:text-primary transition-colors duration-300">
          <div className="p-2 rounded-lg bg-primary/10 group-hover:bg-primary/20 transition-all duration-300 group-hover:scale-110">
            <Sparkles className="h-4 w-4 sm:h-5 sm:w-5 text-primary" />
          </div>
          Inserisci il tuo prompt
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-3 sm:space-y-4">
        <Textarea
          placeholder="Scrivi qui cosa vuoi generare..."
          value={prompt}
          onChange={(e) => setPrompt(e.target.value)}
          className="min-h-[200px] sm:min-h-[300px] resize-none text-sm sm:text-base bg-background/50 border-border/50 focus:border-primary focus:ring-2 focus:ring-primary/20 transition-all duration-300 rounded-xl hover:bg-background/70"
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
              <Sparkles className="mr-2 h-4 w-4 sm:h-5 sm:w-5 group-hover:rotate-12 transition-transform duration-300" />
              Genera
            </>
          )}
        </Button>
      </CardContent>
    </Card>
  );
};

export default TextGenerator;