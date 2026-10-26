import 'package:flutter/material.dart';

class ArabCountry {
  final String code;
  final String dialCode;
  final String flag;
  final String nameAr;
  final String nameEn;
  final String nameFr;

  const ArabCountry({
    required this.code,
    required this.dialCode,
    required this.flag,
    required this.nameAr,
    required this.nameEn,
    required this.nameFr,
  });

  String localizedName(String lang) {
    if (lang == 'ar') return nameAr;
    if (lang == 'fr') return nameFr;
    return nameEn;
  }
}

const List<ArabCountry> arabCountries = [
  ArabCountry(code: 'TN', dialCode: '+216', flag: '🇹🇳', nameAr: 'تونس', nameEn: 'Tunisia', nameFr: 'Tunisie'),
  ArabCountry(code: 'DZ', dialCode: '+213', flag: '🇩🇿', nameAr: 'الجزائر', nameEn: 'Algeria', nameFr: 'Algérie'),
  ArabCountry(code: 'MA', dialCode: '+212', flag: '🇲🇦', nameAr: 'المغرب', nameEn: 'Morocco', nameFr: 'Maroc'),
  ArabCountry(code: 'EG', dialCode: '+20', flag: '🇪🇬', nameAr: 'مصر', nameEn: 'Egypt', nameFr: 'Égypte'),
  ArabCountry(code: 'LY', dialCode: '+218', flag: '🇱🇾', nameAr: 'ليبيا', nameEn: 'Libya', nameFr: 'Libye'),
  ArabCountry(code: 'MR', dialCode: '+222', flag: '🇲🇷', nameAr: 'موريتانيا', nameEn: 'Mauritania', nameFr: 'Mauritanie'),
  ArabCountry(code: 'SD', dialCode: '+249', flag: '🇸🇩', nameAr: 'السودان', nameEn: 'Sudan', nameFr: 'Soudan'),
  ArabCountry(code: 'SA', dialCode: '+966', flag: '🇸🇦', nameAr: 'السعودية', nameEn: 'Saudi Arabia', nameFr: 'Arabie Saoudite'),
  ArabCountry(code: 'AE', dialCode: '+971', flag: '🇦🇪', nameAr: 'الإمارات', nameEn: 'United Arab Emirates', nameFr: 'Émirats Arabes Unis'),
  ArabCountry(code: 'QA', dialCode: '+974', flag: '🇶🇦', nameAr: 'قطر', nameEn: 'Qatar', nameFr: 'Qatar'),
  ArabCountry(code: 'KW', dialCode: '+965', flag: '🇰🇼', nameAr: 'الكويت', nameEn: 'Kuwait', nameFr: 'Koweït'),
  ArabCountry(code: 'OM', dialCode: '+968', flag: '🇴🇲', nameAr: 'عُمان', nameEn: 'Oman', nameFr: 'Oman'),
  ArabCountry(code: 'BH', dialCode: '+973', flag: '🇧🇭', nameAr: 'البحرين', nameEn: 'Bahrain', nameFr: 'Bahreïn'),
  ArabCountry(code: 'JO', dialCode: '+962', flag: '🇯🇴', nameAr: 'الأردن', nameEn: 'Jordan', nameFr: 'Jordanie'),
  ArabCountry(code: 'LB', dialCode: '+961', flag: '🇱🇧', nameAr: 'لبنان', nameEn: 'Lebanon', nameFr: 'Liban'),
  ArabCountry(code: 'IQ', dialCode: '+964', flag: '🇮🇶', nameAr: 'العراق', nameEn: 'Iraq', nameFr: 'Irak'),
  ArabCountry(code: 'PS', dialCode: '+970', flag: '🇵🇸', nameAr: 'فلسطين', nameEn: 'Palestine', nameFr: 'Palestine'),
  ArabCountry(code: 'SY', dialCode: '+963', flag: '🇸🇾', nameAr: 'سوريا', nameEn: 'Syria', nameFr: 'Syrie'),
  ArabCountry(code: 'YE', dialCode: '+967', flag: '🇾🇪', nameAr: 'اليمن', nameEn: 'Yemen', nameFr: 'Yémen'),
  ArabCountry(code: 'SO', dialCode: '+252', flag: '🇸🇴', nameAr: 'الصومال', nameEn: 'Somalia', nameFr: 'Somalie'),
  ArabCountry(code: 'DJ', dialCode: '+253', flag: '🇩🇯', nameAr: 'جيبوتي', nameEn: 'Djibouti', nameFr: 'Djibouti'),
  ArabCountry(code: 'KM', dialCode: '+269', flag: '🇰🇲', nameAr: 'جزر القمر', nameEn: 'Comoros', nameFr: 'Comores'),
];

ArabCountry getArabCountry(String code) {
  final upper = code.toUpperCase();
  return arabCountries.firstWhere(
    (c) => c.code == upper,
    orElse: () => arabCountries.first, // Defaults to Tunisia
  );
}

class ArabCountryPickerField extends StatelessWidget {
  final ArabCountry selectedCountry;
  final ValueChanged<ArabCountry> onCountryChanged;
  final TextEditingController phoneController;
  final String currentLang;

  const ArabCountryPickerField({
    super.key,
    required this.selectedCountry,
    required this.onCountryChanged,
    required this.phoneController,
    this.currentLang = 'ar',
  });

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Text(
                          '🌍',
                          style: TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currentLang == 'ar'
                              ? 'اختر الدولة العربية'
                              : currentLang == 'fr'
                                  ? 'Choisir le pays arabe'
                                  : 'Select Arab Country',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: arabCountries.length,
                      itemBuilder: (ctx, idx) {
                        final country = arabCountries[idx];
                        final isSelected = country.code == selectedCountry.code;
                        return ListTile(
                          leading: Text(
                            country.flag,
                            style: const TextStyle(fontSize: 26),
                          ),
                          title: Text(
                            country.localizedName(currentLang),
                            style: TextStyle(
                              color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: Text(
                            country.dialCode,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          tileColor: isSelected ? const Color(0xFF0F172A) : null,
                          onTap: () {
                            onCountryChanged(country);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => _showPicker(context),
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedCountry.flag,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    selectedCountry.dialCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 20),
                ],
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                hintText: currentLang == 'ar'
                    ? 'رقم الهاتف (مثال: 98123456)'
                    : currentLang == 'fr'
                        ? 'Numéro de téléphone'
                        : 'Phone number',
                hintStyle: const TextStyle(color: Colors.white38),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
