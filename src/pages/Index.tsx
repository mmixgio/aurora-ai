import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { History } from "lucide-react";
import Navbar from "@/components/Navbar";
import TextGenerator from "@/components/TextGenerator";
import ImageGenerator from "@/components/ImageGenerator";
import OutputPanel from "@/components/OutputPanel";
import HistorySidebar from "@/components/HistorySidebar";
import Footer from "@/components/Footer";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import type { User as SupabaseUser } from "@supabase/supabase-js";

const Index = () => {
  const navigate = useNavigate();
  const [user, setUser] = useState<SupabaseUser | null>(null);
  const [generatedText, setGeneratedText] = useState("");
  const [historyOpen, setHistoryOpen] = useState(false);

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
    <div className="min-h-screen bg-gradient-to-br from-background via-background to-accent/5 flex flex-col relative">
      <Navbar />
      
      {/* History Button - Fixed top left */}
      <Button
        onClick={() => setHistoryOpen(true)}
        className="fixed top-20 left-4 z-40 rounded-full shadow-lg hover:shadow-xl transition-all duration-300 hover:scale-110 p-3 sm:p-4"
        size="icon"
      >
        <History className="h-5 w-5" />
      </Button>

      {/* History Sidebar */}
      <HistorySidebar open={historyOpen} onOpenChange={setHistoryOpen} />
      
      <main className="container mx-auto px-4 sm:px-6 lg:px-8 py-8 sm:py-12 lg:py-16 flex-1">
        <div className="max-w-5xl mx-auto">
          {/* Header */}
          <div className="text-center mb-8 sm:mb-12 animate-fade-in">
            <h1 className="text-3xl sm:text-4xl md:text-5xl font-bold tracking-tight mb-3 sm:mb-4 bg-gradient-to-r from-foreground via-foreground to-primary bg-clip-text text-transparent">
              Crea con l'AI
            </h1>
            <p className="text-muted-foreground text-base sm:text-lg max-w-2xl mx-auto leading-relaxed">
              Genera testo e immagini con Aurora, il tuo assistente creativo AI
            </p>
          </div>

          {/* ChatGPT-like Layout */}
          <div className="space-y-6 sm:space-y-8 animate-fade-in">
            {/* Input Section */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 sm:gap-6">
              <div className="transform hover:scale-[1.01] transition-all duration-300">
                <TextGenerator onTextGenerated={handleTextGenerated} />
              </div>
              <div className="transform hover:scale-[1.01] transition-all duration-300">
                <ImageGenerator onImageGenerated={handleImageGenerated} />
              </div>
            </div>

            {/* Output Section */}
            <div className="transform hover:scale-[1.01] transition-all duration-300">
              <OutputPanel generatedText={generatedText} />
            </div>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  );
};

export default Index;