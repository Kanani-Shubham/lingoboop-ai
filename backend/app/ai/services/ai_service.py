import json
import re
from typing import Any, Dict, List, Optional
from app.ai.providers.groq_provider import GroqProvider
from app.ai.schemas.ai_schemas import (
    AITutorRequest,
    AITutorResponse,
    ConversationTurn,
    DailyPracticeItem,
    DailyPracticeRequest,
    DailyPracticeResponse,
    GrammarCorrectionRequest,
    GrammarCorrectionResponse,
    VocabularyItem,
)
from app.core.config import settings

# Character persona descriptions matching polypet-demo.html
PET_PERSONAS = {
    "fox": "You are Maru, a clever, energetic orange fox companion who loves words, idioms, and quick conversation. You speak enthusiastically and encourage learners warmly.",
    "cat": "You are Mimi, a stylish, sharp-witted lavender cat who appreciates precise grammar, elegant pronunciation, and thoughtful phrasing.",
    "rabbit": "You are Bun, an affectionate, cheerful yellow bunny who loves simple daily conversations, warm greetings, and celebrating every little achievement.",
    "panda": "You are Pano, a gentle, wise teal panda who is calm, reassuring, and helps learners practice slowly without feeling rushed or self-conscious.",
    "chick": "You are Pip, a curious, peppy green chick who asks fun follow-up questions and loves discovering new vocabulary words together.",
    "lion": "You are Leo, a noble, encouraging coral lion who inspires courage in speaking out loud and making confident practice mistakes.",
}

LANGUAGE_NAMES = {
    "gu": "Gujarati",
    "gu-in": "Gujarati",
    "hi": "Hindi",
    "hi-in": "Hindi",
    "en": "English",
    "en-us": "English",
    "en-in": "English",
    "ta": "Tamil",
    "ta-in": "Tamil",
    "te": "Telugu",
    "te-in": "Telugu",
    "mr": "Marathi",
    "mr-in": "Marathi",
    "bn": "Bengali",
    "bn-in": "Bengali",
    "es": "Spanish",
    "fr": "French",
    "ja": "Japanese",
}


class AIService:
    """
    Central AI Intelligence Orchestrator.
    Manages Groq openai/gpt-oss-120b inference, persona adaptation, structured JSON synthesis,
    and fallback handling.
    """

    def __init__(self, provider: Optional[GroqProvider] = None):
        self.provider = provider or GroqProvider()

    def _build_system_prompt(self, req: AITutorRequest) -> str:
        pet_key = (req.character_id or "fox").lower()
        persona = PET_PERSONAS.get(pet_key, PET_PERSONAS["fox"])

        native_lang_code = req.native_language.lower().split("-")[0]
        target_lang_code = req.target_language.lower().split("-")[0]
        native_lang_name = LANGUAGE_NAMES.get(native_lang_code, req.native_language)
        target_lang_name = LANGUAGE_NAMES.get(target_lang_code, req.target_language)

        return f"""{persona}
You are an expert AI language tutor and speaking partner for LingoBoom.
The learner's native language is {native_lang_name} ({req.native_language}) and their target learning language is {target_lang_name} ({req.target_language}).
Learner proficiency level: {req.proficiency_level}.

CRITICAL INSTRUCTIONS:
1. When the user speaks or writes in {native_lang_name}, translate their sentence accurately into natural {target_lang_name}.
2. When the user speaks or writes in {target_lang_name}, review their grammar:
   - If incorrect, provide a gentle correction in "correction" and explain the mistake simply in {native_lang_name} in "explanation".
   - If correct, set "correction" to null and provide a short compliment or insight in "explanation".
3. "reply_text": Your spoken conversational response to the user in {target_lang_name} (keep it friendly, natural, and concise - 1 to 2 sentences max so it can be spoken via Text-to-Speech).
4. "examples": Provide 1 to 2 natural alternative ways to say the sentence.
5. "pronunciation_guide": Provide a clear phonetic pronunciation guide for the translated sentence or reply.
6. Never invent non-existent grammar rules. Be warm, patient, and never make the learner feel embarrassed.

YOU MUST ALWAYS RESPOND IN STRICT VALID JSON MATCHING THIS EXACT SCHEMA:
{{
  "source_text": string,
  "translated_text": string,
  "detected_language": string (ISO 639-1 e.g. "gu", "hi", "en"),
  "target_language": string (ISO 639-1 e.g. "en", "gu", "hi"),
  "correction": string or null,
  "explanation": string,
  "examples": [string],
  "reply_text": string,
  "pronunciation_guide": string,
  "vocabulary_breakdown": [
    {{"word": string, "meaning": string, "part_of_speech": string, "example": string}}
  ],
  "conversation_mode": "learning"
}}"""

    async def tutor_interaction(self, req: AITutorRequest) -> AITutorResponse:
        """
        Processes learner input through Groq openai/gpt-oss-120b and returns a structured response.
        """
        # If Groq key is not yet configured, provide safe instructional fallback
        if not settings.is_groq_configured():
            return self._build_unconfigured_fallback(req)

        system_prompt = self._build_system_prompt(req)

        messages: List[Dict[str, str]] = [{"role": "system", "content": system_prompt}]

        # Append recent bounded history (max 6 turns to manage token window)
        bounded_history = req.history[-6:] if req.history else []
        for turn in bounded_history:
            messages.append({"role": turn.role, "content": turn.content})

        # Append current user message
        messages.append({"role": "user", "content": req.user_message})

        try:
            raw_content = await self.provider.chat_completion(
                messages=messages,
                model=settings.GROQ_MODEL,
                temperature=0.3,
                max_tokens=1024,
                response_format={"type": "json_object"},
            )

            parsed_data = self._clean_and_parse_json(raw_content)
            return AITutorResponse(
                source_text=parsed_data.get("source_text") or req.user_message,
                translated_text=parsed_data.get("translated_text") or req.user_message,
                detected_language=parsed_data.get("detected_language") or req.native_language[:2],
                target_language=parsed_data.get("target_language") or req.target_language[:2],
                correction=parsed_data.get("correction"),
                explanation=parsed_data.get("explanation"),
                examples=parsed_data.get("examples") or [],
                reply_text=parsed_data.get("reply_text") or parsed_data.get("translated_text") or "Keep practicing!",
                pronunciation_guide=parsed_data.get("pronunciation_guide"),
                vocabulary_breakdown=[
                    VocabularyItem(**item) for item in parsed_data.get("vocabulary_breakdown", [])
                    if isinstance(item, dict) and "word" in item and "meaning" in item
                ] if parsed_data.get("vocabulary_breakdown") else None,
                conversation_mode=parsed_data.get("conversation_mode") or "learning",
                provider="groq",
                model=settings.GROQ_MODEL,
            )

        except Exception as e:
            # Handle upstream provider errors gracefully
            if isinstance(e, json.JSONDecodeError):
                return self._build_resilient_fallback(req, f"AI response formatting issue: {str(e)[:60]}")
            raise e

    def _clean_and_parse_json(self, raw_str: str) -> Dict[str, Any]:
        """Strip markdown fences (```json ... ```) and extract valid JSON."""
        cleaned = raw_str.strip()
        if cleaned.startswith("```"):
            cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
            cleaned = re.sub(r"\s*```$", "", cleaned)
        return json.loads(cleaned)

    def _build_unconfigured_fallback(self, req: AITutorRequest) -> AITutorResponse:
        """Returns a helpful structured message when GROQ_API_KEY is not yet added."""
        clean_text = req.user_message.strip()
        return AITutorResponse(
            source_text=clean_text,
            translated_text=clean_text,
            detected_language=req.native_language[:2],
            target_language=req.target_language[:2],
            correction=None,
            explanation="Groq API key is not yet configured. Please add GROQ_API_KEY to backend/.env to activate GPT-OSS 120B intelligence.",
            examples=[clean_text],
            reply_text=f"Hello! I am ready to practice with you once your Groq API key is added.",
            pronunciation_guide=None,
            vocabulary_breakdown=None,
            conversation_mode="setup_required",
            provider="lingoboom_local_gateway",
            model="unconfigured",
        )

    def _build_resilient_fallback(self, req: AITutorRequest, reason: str) -> AITutorResponse:
        clean_text = req.user_message.strip()
        return AITutorResponse(
            source_text=clean_text,
            translated_text=clean_text,
            detected_language=req.native_language[:2],
            target_language=req.target_language[:2],
            correction=None,
            explanation=reason,
            examples=[clean_text],
            reply_text=f"Let's practice: {clean_text}",
            pronunciation_guide=None,
            vocabulary_breakdown=None,
            conversation_mode="resilient_mode",
            provider="groq_fallback",
            model=settings.GROQ_MODEL,
        )


    async def generate_daily_practice(self, req: DailyPracticeRequest) -> DailyPracticeResponse:
        """Generates 20-30 curated, everyday spoken sentences for daily practice."""
        import datetime
        today_str = datetime.date.today().isoformat()

        native_lang_code = req.native_language.lower().split("-")[0]
        target_lang_code = req.target_language.lower().split("-")[0]
        native_lang_name = LANGUAGE_NAMES.get(native_lang_code, req.native_language)
        target_lang_name = LANGUAGE_NAMES.get(target_lang_code, req.target_language)

        category_instruction = (
            f"Focus particularly on category: {req.category}."
            if req.category
            else "Include an even mix across: daily conversation, self-introduction, shopping, ordering food, asking directions, travel, education, workplace, friends, phone, and common questions."
        )

        if not settings.is_groq_configured():
            return self._build_offline_daily_practice(req, today_str)

        prompt = f"""You are an elite multilingual language curriculum architect for TalkTails.
Generate exactly {req.count} practical everyday speaking practice sentences for a learner at '{req.proficiency_level}' level.
The learner's native language is {native_lang_name} ({req.native_language}) and target language is {target_lang_name} ({req.target_language}).
{category_instruction}

Each sentence MUST be natural, commonly spoken in real life, and grammatically impeccable.
Avoid repetitive templates. Ensure sentences range from simple everyday exchanges to expressive phrases.

YOU MUST RESPOND ONLY IN STRICT VALID JSON MATCHING THIS EXACT FORMAT:
{{
  "date": "{today_str}",
  "native_language": "{req.native_language}",
  "target_language": "{req.target_language}",
  "proficiency_level": "{req.proficiency_level}",
  "sentences": [
    {{
      "id": "practice_1",
      "target_sentence": "Where is the nearest railway station?",
      "native_translation": "નજીકનું રેલવે સ્ટેશન ક્યાં છે?",
      "category": "Asking Directions",
      "difficulty": "{req.proficiency_level}",
      "pronunciation_guide": "Where iz the neer-est rayl-way stay-shun?",
      "context_tip": "Use this when asking for directions in public places."
    }}
  ]
}}"""

        try:
            raw_content = await self.provider.chat_completion(
                messages=[{"role": "user", "content": prompt}],
                model=settings.GROQ_MODEL,
                temperature=0.3,
                max_tokens=3000,
                response_format={"type": "json_object"},
            )
            parsed_data = self._clean_and_parse_json(raw_content)
            items = []
            for idx, item in enumerate(parsed_data.get("sentences", [])):
                if isinstance(item, dict) and "target_sentence" in item:
                    items.append(
                        DailyPracticeItem(
                            id=item.get("id") or f"sent_{idx+1}",
                            target_sentence=item.get("target_sentence", "").strip(),
                            native_translation=item.get("native_translation", "").strip(),
                            category=item.get("category", "General"),
                            difficulty=item.get("difficulty", req.proficiency_level),
                            pronunciation_guide=item.get("pronunciation_guide"),
                            context_tip=item.get("context_tip"),
                        )
                    )
            if items:
                return DailyPracticeResponse(
                    date=today_str,
                    native_language=req.native_language,
                    target_language=req.target_language,
                    proficiency_level=req.proficiency_level,
                    sentences=items,
                )
        except Exception as e:
            pass

        return self._build_offline_daily_practice(req, today_str)

    def _build_offline_daily_practice(self, req: DailyPracticeRequest, today_str: str) -> DailyPracticeResponse:
        """Curated offline multilingual fallback set of practical everyday sentences."""
        src_code = req.native_language.lower().split("-")[0]
        tgt_code = req.target_language.lower().split("-")[0]

        # Multilingual phrase matrix across major supported languages
        multilingual_phrases = [
            {
                "cat": "Asking Directions",
                "translations": {
                    "en": "Where is the nearest railway station?",
                    "gu": "નજીકનું રેલવે સ્ટેશન ક્યાં છે?",
                    "bn": "কাছের রেলওয়ে স্টেশনটি কোথায়?",
                    "hi": "निकटतम रेलवे स्टेशन कहाँ है?",
                    "ta": "அருகிலுள்ள ரயில் நிலையம் எங்கே உள்ளது?",
                    "te": "సమీపంలోని రైల్వే స్టేషన్ ఎక్కడ ఉంది?",
                    "mr": "जवळचे रेल्वे स्टेशन कुठे आहे?",
                },
                "guide": "Where iz the neer-est rayl-way stay-shun?",
            },
            {
                "cat": "Ordering Food",
                "translations": {
                    "en": "Please give me two cups of hot tea.",
                    "gu": "કૃપા કરીને મને બે કપ ગરમ ચા આપો.",
                    "bn": "দয়া করে আমাকে দুই কাপ গরম চা দিন।",
                    "hi": "कृपया मुझे दो कप गर्म चाय दीजिए।",
                    "ta": "தயவுசெய்து எனக்கு இரண்டு சூடான தேநீர் கொடுங்கள்.",
                    "te": "దయచేసి నాకు రెండు కప్పుల వేడి టీ ఇవ్వండి.",
                    "mr": "कृपया मला दोन कप गरम चहा द्या.",
                },
                "guide": "Pleez giv mee too cups ov hot tee.",
            },
            {
                "cat": "Self-Introduction",
                "translations": {
                    "en": "Hello, I am learning this language.",
                    "gu": "નમસ્તે, હું આ ભાષા શીખી રહ્યો છું.",
                    "bn": "নমস্কার, আমি এই ভাষাটি শিখছি।",
                    "hi": "नमस्ते, मैं यह भाषा सीख रहा हूँ।",
                    "ta": "வணக்கம், நான் இந்த மொழியைக் கற்றுக்கொள்கிறேன்.",
                    "te": "నమస్కారం, నేను ఈ భాష నేర్చుకుంటున్నాను.",
                    "mr": "नमस्कार, मी ही भाषा शिकत आहे.",
                },
                "guide": "Hel-loh, eye am ler-ning this lang-gwij.",
            },
            {
                "cat": "Shopping",
                "translations": {
                    "en": "How much does this item cost?",
                    "gu": "આ કેટલાનું છે?",
                    "bn": "এটার দাম কত?",
                    "hi": "इसकी कीमत कितनी है?",
                    "ta": "இதன் விலை என்ன?",
                    "te": "దీని ధర ఎంత?",
                    "mr": "याची किंमत किती आहे?",
                },
                "guide": "How much duz this eye-tem kost?",
            },
            {
                "cat": "Daily Conversation",
                "translations": {
                    "en": "Could you please speak a little slower?",
                    "gu": "શું તમે થોડું ધીમે બોલી શકશો?",
                    "bn": "আপনি কি একটু ধীরে কথা বলতে পারবেন?",
                    "hi": "क्या आप थोड़ा धीरे बोल सकते हैं?",
                    "ta": "தயவுசெய்து கொஞ்சம் மெதுவாக பேச முடியுமா?",
                    "te": "మీరు కొంచెం నెమ్మదిగా మాట్లాడగలరా?",
                    "mr": "तुम्ही थोडे हळू बोलू शकाल का?",
                },
                "guide": "Kood yoo pleez speek uh lit-ul sloh-er?",
            },
            {
                "cat": "Travel",
                "translations": {
                    "en": "I need help with my luggage.",
                    "gu": "મને મારા સામાનમાં મદદ જોઈએ છે.",
                    "bn": "আমার লাগেজ নিয়ে একটু সাহায্য দরকার।",
                    "hi": "मुझे अपने सामान के साथ मदद चाहिए।",
                    "ta": "எனது சாமான்களுக்கு உதவி தேவை.",
                    "te": "నా లగేజీతో నాకు సహాయం కావాలి.",
                    "mr": "मला माझ्या सामानासाठी मदत हवी आहे.",
                },
                "guide": "Eye need help with my luh-gij.",
            },
            {
                "cat": "Ordering Food",
                "translations": {
                    "en": "Can I get the bill, please?",
                    "gu": "શું મને બિલ મળી શકે?",
                    "bn": "দয়া করে বিলটা কি পেতে পারি?",
                    "hi": "क्या मुझे बिल मिल सकता है?",
                    "ta": "தயவுசெய்து எனக்கு பில் கிடைக்குமா?",
                    "te": "దయచేసి నాకు బిల్ ఇవ్వగలరా?",
                    "mr": "मला बिल मिळू शकेल का?",
                },
                "guide": "Kan eye get thuh bil, pleez?",
            },
            {
                "cat": "Shopping",
                "translations": {
                    "en": "What time does the store open?",
                    "gu": "દુકાન કેટલા વાગ્યે ખુલે છે?",
                    "bn": "দোকানটি কখন খোলে?",
                    "hi": "दुकान कितने बजे खुलती है?",
                    "ta": "கடை எத்தனை மணிக்கு திறக்கும்?",
                    "te": "దుకాణం ఏ సమయానికి తెరుస్తారు?",
                    "mr": "दुकान किती वाजता उघडते?",
                },
                "guide": "Waht tyme duz thuh stor oh-pen?",
            },
            {
                "cat": "Self-Introduction",
                "translations": {
                    "en": "It is very nice to meet you.",
                    "gu": "તમને મળીને ઘણો આનંદ થયો.",
                    "bn": "আপনার সাথে দেখা করে খুব ভালো লাগলো।",
                    "hi": "आपसे मिलकर बहुत अच्छा लगा।",
                    "ta": "உங்களை சந்தித்ததில் மிக்க மகிழ்ச்சி.",
                    "te": "మిమ్మల్ని కలవడం చాలా సంతోషంగా ఉంది.",
                    "mr": "तुम्हाला भेटून खूप आनंद झाला.",
                },
                "guide": "It iz ve-ree nys too meet yoo.",
            },
            {
                "cat": "Daily Conversation",
                "translations": {
                    "en": "Could you repeat that once more?",
                    "gu": "શું તમે એક વાર ફરીથી બોલશો?",
                    "bn": "আপনি কি এটি আর একবার বলতে পারেন?",
                    "hi": "क्या आप इसे एक बार फिर दोहरा सकते हैं?",
                    "ta": "இதை மீண்டும் ஒருமுறை கூற முடியுமா?",
                    "te": "దీన్ని మరోసారి చెప్పగలరా?",
                    "mr": "तुम्ही पुन्हा एकदा सांगू शकाल का?",
                },
                "guide": "Kood yoo ree-peet that wuns mor?",
            },
            {
                "cat": "Asking Directions",
                "translations": {
                    "en": "I am looking for the entrance.",
                    "gu": "હું પ્રવેશદ્વાર શોધી રહ્યો છું.",
                    "bn": "আমি প্রবেশদ্বার খুঁজছি।",
                    "hi": "मैं प्रवेश द्वार ढूंढ रहा हूँ।",
                    "ta": "நான் நுழைவு வாயிலை தேடுகிறேன்.",
                    "te": "నేను ప్రవేశ ద్వారం కోసం చూస్తున్నాను.",
                    "mr": "मी प्रवेशद्वार शोधत आहे.",
                },
                "guide": "Eye am look-ing for thuh en-trans.",
            },
            {
                "cat": "Interviews",
                "translations": {
                    "en": "I am prepared for the discussion today.",
                    "gu": "હું આજે ચર્ચા માટે તૈયાર છું.",
                    "bn": "আমি আজকের আলোচনার জন্য প্রস্তুত।",
                    "hi": "मैं आज की चर्चा के लिए तैयार हूँ।",
                    "ta": "இன்றைய கலந்துரையாடலுக்கு நான் தயாராக உள்ளேன்.",
                    "te": "ఈరోజు చర్చకు నేను సిద్ధంగా ఉన్నాను.",
                    "mr": "मी आजच्या चर्चेसाठी तयार आहे.",
                },
                "guide": "Eye am pre-paird for thuh dis-kush-un tuh-day.",
            },
            {
                "cat": "Workplace Communication",
                "translations": {
                    "en": "Let us schedule a meeting tomorrow.",
                    "gu": "ચાલો આવતીકાલે મીટિંગ રાખીએ.",
                    "bn": "আসুন আগামীকাল একটি মিটিং নির্ধারণ করি।",
                    "hi": "आइए कल एक बैठक निर्धारित करें।",
                    "ta": "நாளை ஒரு சந்திப்பை ஏற்பாடு செய்வோம்.",
                    "te": "రేపు ఒక సమావేశాన్ని ఏర్పాటు చేసుకుందాం.",
                    "mr": "चला उद्या एक बैठक ठरवूया.",
                },
                "guide": "Let us sked-yool uh mee-ting tuh-mor-oh.",
            },
            {
                "cat": "Daily Conversation",
                "translations": {
                    "en": "Thank you very much for your kind help.",
                    "gu": "તમારી મદદ માટે ખૂબ ખૂબ આભાર.",
                    "bn": "আপনার সদয় সাহায্যের জন্য আপনাকে অনেক ধন্যবাদ।",
                    "hi": "आपकी उदार सहायता के लिए बहुत-बहुत धन्यवाद।",
                    "ta": "உங்கள் கனிவான உதவிக்கு மிக்க நன்றி.",
                    "te": "మీ దయతో కూడిన సహాయానికి చాలా ధన్యవాదాలు.",
                    "mr": "तुमच्या मदतीबद्दल खूप खूप धन्यवाद.",
                },
                "guide": "Thank yoo ve-ree much for yoor kynd help.",
            },
        ]

        items = []
        for i, entry in enumerate(multilingual_phrases[: req.count]):
            cat = entry["cat"]
            t_map = entry["translations"]
            # Extract target and native sentences based on requested language pair
            target_text = t_map.get(tgt_code) or t_map.get("en", "")
            native_text = t_map.get(src_code) or t_map.get("gu") or t_map.get("en", "")
            guide = entry["guide"] if tgt_code == "en" else None

            items.append(
                DailyPracticeItem(
                    id=f"curated_{i+1}",
                    target_sentence=target_text,
                    native_translation=native_text,
                    category=cat,
                    difficulty=req.proficiency_level,
                    pronunciation_guide=guide,
                    context_tip=f"Everyday spoken practice for {cat}.",
                )
            )

        return DailyPracticeResponse(
            date=today_str,
            native_language=req.native_language,
            target_language=req.target_language,
            proficiency_level=req.proficiency_level,
            sentences=items,
        )


ai_service = AIService()

