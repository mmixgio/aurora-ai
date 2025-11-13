import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Card } from "@/components/ui/card";
import { Sparkles, Loader2 } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";

interface TextGeneratorProps {
  onTextGenerated: (text: string) => void;
}

const TextGenerator = ({ onTextGenerated }: TextGeneratorProps) => {
  const [prompt, setPrompt] = useState("");
  const [isGenerating, setIsGenerating] = useState(false);

  const handleGenerate = async () => {
    if (!prompt.trim()) {
      toast.error("Please enter a prompt");
      return;
    }

    setIsGenerating(true);

    try {
      const { data, error } = await supabase.functions.invoke('generate-text', {
        body: { prompt }
      });

      if (error) throw error;

      if (data?.text) {
        onTextGenerated(data.text);
        toast.success("Text generated successfully!");
        setPrompt("");
      } else {
        throw new Error("No text generated");
      }
    } catch (error: any) {
      console.error('Text generation error:', error);
      toast.error(error.message || "Failed to generate text");
    } finally {
      setIsGenerating(false);
    }
  };

  return (
    <Card className="p-6 space-y-4 shadow-md border border-border/50">
      <div className="flex items-center gap-2 mb-2">
        <Sparkles className="h-5 w-5 text-primary" />
        <h3 className="text-lg font-semibold text-foreground">Text Generator</h3>
      </div>
      
      <Textarea
        placeholder="Describe what you want to create..."
        value={prompt}
        onChange={(e) => setPrompt(e.target.value)}
        className="min-h-[120px] resize-none border-border/50 focus:border-primary transition-colors"
      />
      
      <Button 
        onClick={handleGenerate}
        disabled={isGenerating}
        className="w-full bg-primary hover:bg-primary-hover text-primary-foreground transition-all duration-300 shadow-sm hover:shadow-md"
      >
        {isGenerating ? (
          <>
            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            Generating...
          </>
        ) : (
          <>
            <Sparkles className="mr-2 h-4 w-4" />
            Generate Text
          </>
        )}
      </Button>
    </Card>
  );
};

export default TextGenerator;