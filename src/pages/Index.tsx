import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import Navbar from "@/components/Navbar";
import TextGenerator from "@/components/TextGenerator";
import ImageGenerator from "@/components/ImageGenerator";
import OutputPanel from "@/components/OutputPanel";
import GenerationsHistory from "@/components/GenerationsHistory";
import Footer from "@/components/Footer";
import { supabase } from "@/integrations/supabase/client";
import type { User as SupabaseUser } from "@supabase/supabase-js";

const Index = () => {
  const navigate = useNavigate();
  const [user, setUser] = useState<SupabaseUser | null>(null);
  const [generatedText, setGeneratedText] = useState("");

  useEffect(() => {
    const checkUser = async () => {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        navigate("/auth");
        return;
      }
      setUser(session.user);
    };
    checkUser();

    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (!session) {
        navigate("/auth");
      } else {
        setUser(session.user);
      }
    });

    return () => subscription.unsubscribe();
  }, [navigate]);

  const handleTextGenerated = (text: string) => {
    setGeneratedText(text);
  };

  const handleImageGenerated = (imageUrl: string) => {
    // Image is now saved in database by ImageGenerator component
    console.log('Image generated:', imageUrl);
  };

  if (!user) {
    return null;
  }

  return (
    <div className="min-h-screen bg-background flex flex-col">
      <Navbar />
      
      <main className="container mx-auto px-6 py-12 flex-1">
        <div className="max-w-7xl mx-auto">
          {/* Header */}
          <div className="text-center mb-12 animate-fade-in">
            <h1 className="text-4xl md:text-5xl font-bold tracking-tight mb-4">
              Crea con l'AI
            </h1>
            <p className="text-muted-foreground text-lg max-w-2xl mx-auto">
              Genera testo e immagini con Aurora, il tuo assistente creativo AI
            </p>
          </div>

          {/* Three Column Layout */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 animate-fade-in">
            {/* Left Column - Input */}
            <div className="space-y-6 flex flex-col">
              <TextGenerator onTextGenerated={handleTextGenerated} />
              <ImageGenerator onImageGenerated={handleImageGenerated} />
            </div>

            {/* Middle Column - Output */}
            <div className="flex flex-col">
              <OutputPanel generatedText={generatedText} />
            </div>

            {/* Right Column - History */}
            <div className="flex flex-col">
              <GenerationsHistory />
            </div>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  );
};

export default Index;