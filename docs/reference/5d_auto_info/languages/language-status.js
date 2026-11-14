// CHECK STATUS TEXT
function checkLanguages(value) {
  const statusLanguage = {
      "cs-CZ": {
        "Nový": "new",
        "Existující": "existing",
        "Znovupoužití": "reuse",
        "Dočasný": "temporary",
        "Demolice": "demolition"
      },
      "de-DE": {
        "Neu": "new",
        "Bestehend": "existing",
        "Wiederverwendung": "reuse",
        "Vorübergehend": "temporary",
        "Abbruch": "demolition"
      },
      "en-US": {
        "New": "new",
        "Existing": "existing",
        "Reuse": "reuse",
        "Temporary": "temporary",
        "Demolition": "demolition"
      },
      "es-ES": {
        "Nuevo": "new",
        "Existente": "existing",
        "Reutilizar": "reuse",
        "Temporal": "temporary",
        "Demolición": "demolition"
      },
      "fr-FR": {
        "Nouveau": "new",
        "Existant": "existing",
        "Réutiliser": "reuse",
        "Temporaire": "temporary",
        "Démolition": "demolition"
      },
      "it-IT": {
        "Nuovo": "new",
        "Esistente": "existing",
        "Riutilizza": "reuse",
        "Temporaneo": "temporary",
        "Demolizione": "demolition"
      },
      "ja-JP": {
        "新規": "new",
        "既存": "existing",
        "再利用": "reuse",
        "一時的": "temporary",
        "解体": "demolition"
      },
      "ko-KR": {
        "새로운": "new",
        "기존": "existing",
        "재사용": "reuse",
        "임시": "temporary",
        "철거": "demolition"
      },
      "nl-NL": {
        "Nieuw": "new",
        "Bestaand": "existing",
        "Herbruik": "reuse",
        "Tijdelijk": "temporary",
        "Sloop": "demolition"
      },
      "pl-PL": {
        "Nowy": "new",
        "Istniejący": "existing",
        "Ponowne użycie": "reuse",
        "Tymczasowy": "temporary",
        "Demontaż": "demolition"
      },
      "pt-BR": {
        "Novo": "new",
        "Existente": "existing",
        "Reutilizar": "reuse",
        "Temporário": "temporary",
        "Demolição": "demolition"
      },
      "ru-RU": {
        "Новый": "new",
        "Существующий": "existing",
        "Повторное использование": "reuse",
        "Временный": "temporary",
        "Демонтаж": "demolition"
      },
      "sk-SK": {
        "Nový": "new",
        "Existujúci": "existing",
        "Znovu použiť": "reuse",
        "Dočasný": "temporary",
        "Demolácia": "demolition"
      },
      "sl-SI": {
        "Novo": "new",
        "Obstoječe": "existing",
        "Ponovna uporaba": "reuse",
        "Začasno": "temporary",
        "Rušenje": "demolition"
      },
      "sv-SE": {
        "Ny": "new",
        "Befintlig": "existing",
        "Återanvändning": "reuse",
        "Tillfällig": "temporary",
        "Rivning": "demolition"
      },
      "th-TH": {
        "ใหม่": "new",
        "มีอยู่": "existing",
        "ใช้ซ้ำ": "reuse",
        "ชั่วคราว": "temporary",
        "ทำลาย": "demolition"
      },
      "tr-TR": {
        "Yeni": "new",
        "Mevcut": "existing",
        "Yeniden Kullanım": "reuse",
        "Geçici": "temporary",
        "Yıkım": "demolition"
      },
      "uk-UA": {
        "Новий": "new",
        "Існуючий": "existing",
        "Перевикористання": "reuse",
        "Тимчасовий": "temporary",
        "Знесення": "demolition"
      },
      "vi-VN": {
        "Mới": "new",
        "Hiện hữu": "existing",
        "Dùng lại": "reuse",
        "Tạm thời": "temporary",
        "Loại bỏ": "demolition"
      },
      "zh-CN": {
        "New": "新建",
        "Existing": "现有",
        "Reuse": "再利用",
        "Temporary": "临时",
        "Demolition": "拆除"
      }
  };

  let statusKey = null;

  for (const language in statusLanguage) {
    if (statusLanguage[language].hasOwnProperty(value)) {
      statusKey = statusLanguage[language][value];
      break;
    }
  }

  // customLog("1. (Check Status language) Output value: ", statusKey);
  return statusKey;
}