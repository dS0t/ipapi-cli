#include <iostream>
#include <string>
#include <sstream>
#include <iomanip>
#include <fstream>
#include <ctime>
#include <filesystem>
#include <curl/curl.h>
#include "json.hpp"

using json = nlohmann::json;
using namespace std;

// ANSI TrueColor macros (Pastel Palette)
const string C_HEAD_MAIN = "\033[38;2;174;198;207m";
const string C_HEAD_COMP = "\033[38;2;253;253;150m";
const string C_HEAD_ASN  = "\033[38;2;255;179;186m";
const string C_HEAD_LOC  = "\033[38;2;186;255;201m";
const string C_SEP       = "\033[38;2;90;90;90m";
const string C_KEY       = "\033[38;2;110;110;110m";
const string C_VAL       = "\033[38;2;190;190;190m";
const string C_TRUE      = "\033[38;2;119;221;119m";
const string C_FALSE     = "\033[38;2;244;194;194m";
const string C_RST       = "\033[0m";

enum class Mode { DEFAULT, FULL, SHORT, HELP };

static size_t WriteCallback(void *contents, size_t size, size_t nmemb, void *userp) {
    ((string*)userp)->append((char*)contents, size * nmemb);
    return size * nmemb;
}

void print_help() {
    cout << "\n"
         << C_HEAD_MAIN << "╭─┬─┬─╮\n"
         << C_HEAD_MAIN << "├─┼─┼─╯    " << C_VAL << "ipapi CLI\n"
         << C_HEAD_MAIN << "├─┼─╯      " << C_SEP << "v1.0.0\n"
         << C_HEAD_MAIN << "╰─╯\n"
         << C_RST << endl;
         
    cout << C_HEAD_COMP << "USAGE:" << C_RST << "\n"
         << "  " << C_VAL << "./ipa [IP] [OPTIONS]\n\n" << C_RST;
    
    cout << C_HEAD_ASN << "OPTIONS:" << C_RST << "\n"
         << "  " << C_KEY << left << setw(18) << "-h, --help" << C_RST 
         << C_VAL << "Show this beautiful help message" << C_RST << "\n"
         << "  " << C_KEY << left << setw(18) << "-f, --full" << C_RST 
         << C_VAL << "Display full, verbose IP data (location, all flags, etc.)" << C_RST << "\n"
         << "  " << C_KEY << left << setw(18) << "-s, --short" << C_RST 
         << C_VAL << "Output a single-line summary (ideal for bash scripts)" << C_RST << "\n\n"
         << C_SEP << "If no IP is provided, the program queries your current IP.\n" << C_RST << "\n";
}

void print_row(const string& key, const string& val) {
    cout << C_KEY << left << setw(14) << key << C_RST << C_VAL << val << C_RST << endl;
}

void print_colored_row(const string& key, const string& val, const string& color) {
    cout << C_KEY << left << setw(14) << key << C_RST << color << val << C_RST << endl;
}

void print_flag(const string& key, bool val) {
    cout << C_KEY << left << setw(14) << key << C_RST;
    if (val) {
        cout << C_TRUE << "✓" << C_RST << endl;
    } else {
        cout << C_FALSE << "✗" << C_RST << endl;
    }
}

string get_score_color(const string& val) {
    if (val.find("(Very Low)") != string::npos) return "\033[38;2;119;221;119m"; 
    if (val.find("(Low)") != string::npos) return "\033[38;2;170;220;190m"; 
    if (val.find("(Elevated)") != string::npos) return "\033[38;2;253;253;150m"; 
    if (val.find("(Medium)") != string::npos) return "\033[38;2;255;200;150m"; 
    if (val.find("(High)") != string::npos) return "\033[38;2;244;194;194m"; 
    if (val.find("(Very High)") != string::npos) return "\033[38;2;255;105;97m"; 
    if (val.find("(Severe)") != string::npos || val.find("(Critical)") != string::npos) return "\033[38;2;255;105;97m"; 
    return C_VAL;
}

void print_score_row(const string& key, const string& val) {
    string color = get_score_color(val);
    cout << C_KEY << left << setw(14) << key << C_RST << color << val << C_RST << endl;
}

string format_double(double val) {
    stringstream ss;
    ss << val;
    return ss.str();
}

string get_current_date() {
    time_t now = time(0);
    struct tm tstruct;
    char buf[80];
    tstruct = *localtime(&now);
    strftime(buf, sizeof(buf), "%Y-%m-%d", &tstruct);
    return buf;
}

int update_and_get_counter() {
    std::filesystem::path temp_dir = std::filesystem::temp_directory_path();
    std::filesystem::path file_path = temp_dir / "ipa_counter.json";
    string file_path_str = file_path.string();

    string today = get_current_date();
    int count = 0;
    ifstream fin(file_path_str);
    if (fin.is_open()) {
        try {
            json cj; fin >> cj;
            if (cj.contains("date") && cj["date"] == today) count = cj.value("count", 0);
        } catch (...) {}
        fin.close();
    }
    count++;
    ofstream fout(file_path_str);
    if (fout.is_open()) {
        try {
            json cj; cj["date"] = today; cj["count"] = count;
            fout << cj.dump();
        } catch (...) {}
        fout.close();
    }
    return count;
}

int main(int argc, char* argv[]) {
    string ip = "";
    Mode mode = Mode::DEFAULT;

    for (int i = 1; i < argc; i++) {
        string arg = argv[i];
        if (arg == "-f" || arg == "--full") {
            mode = Mode::FULL;
        } else if (arg == "-s" || arg == "--short") {
            mode = Mode::SHORT;
        } else if (arg == "-h" || arg == "--help") {
            mode = Mode::HELP;
        } else {
            ip = arg;
        }
    }
    
    if (mode == Mode::HELP) {
        print_help();
        return 0;
    }

    string url = "https://api.ipapi.is/?q=" + ip;
    CURL *curl;
    CURLcode res;
    string readBuffer;

    curl = curl_easy_init();
    if (curl) {
        struct curl_slist *headers = NULL;
        headers = curl_slist_append(headers, "Referer: https://ipapi.is/");
        curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &readBuffer);
        curl_easy_setopt(curl, CURLOPT_USERAGENT, "ipapi-cli/3.0");
        res = curl_easy_perform(curl);
        if (res != CURLE_OK) {
            cerr << "Connection error: " << curl_easy_strerror(res) << endl;
            curl_slist_free_all(headers);
            curl_easy_cleanup(curl);
            return 1;
        }
        curl_slist_free_all(headers);
        curl_easy_cleanup(curl);
    }

    try {
        auto j = json::parse(readBuffer);
        if (j.contains("error") || !j.contains("ip")) {
            cout << C_TRUE << "Error fetching IP info." << C_RST << endl;
            if (j.contains("message")) cout << C_VAL << j["message"].get<string>() << C_RST << endl;
            else if (j.contains("error")) cout << C_VAL << j["error"].get<string>() << C_RST << endl;
            return 1;
        }

        bool is_full = (mode == Mode::FULL);
        bool is_short = (mode == Mode::SHORT);

        if (is_short) {
            // SHORT MODE LOGIC
            string ip_val = j.value("ip", "Unknown");
            string cc_val = "-";
            if (j.contains("location") && j["location"].is_object()) cc_val = j["location"].value("country_code", j.value("cc", "-"));
            else cc_val = j.value("cc", "-");

            string comp_name = "-";
            string comp_type = "";
            string comp_abuser = "-";
            if (j.contains("company") && j["company"].is_object()) {
                comp_name = j["company"].value("name", "-");
                if (j["company"].contains("type")) comp_type = " (" + j["company"].value("type", "") + ")";
                comp_abuser = j["company"].value("abuser_score", "-");
            } else {
                comp_name = j.value("company_name", "-");
            }

            string asn_abuser = "-";
            if (j.contains("asn") && j["asn"].is_object()) {
                asn_abuser = j["asn"].value("abuser_score", "-");
            }

            bool is_ip_abuser = j.value("is_abuser", false);
            string ip_color = is_ip_abuser ? "\033[38;2;255;105;97m" : C_TRUE; // Bright Red if abuser, Pastel Green if clean

            string pipe = C_SEP + " | " + C_RST;
            
            cout << ip_color << ip_val << C_RST << pipe 
                 << C_VAL << cc_val << C_RST << pipe 
                 << C_VAL << comp_name << comp_type << C_RST << pipe 
                 << get_score_color(comp_abuser) << comp_abuser << C_RST << pipe 
                 << get_score_color(asn_abuser) << asn_abuser << C_RST << endl;
            
            update_and_get_counter();
            return 0;
        }

        // --- MAIN SECTION ---
        cout << "\n" << C_HEAD_MAIN << "MAIN" << C_RST << endl;
        cout << C_SEP << "----" << C_RST << endl;
        
        bool is_ip_abuser = j.value("is_abuser", false);
        string ip_color = is_ip_abuser ? "\033[38;2;255;105;97m" : C_TRUE;
        print_colored_row("ip", j.value("ip", "Unknown"), ip_color);
        
        if (is_full && j.contains("rir")) print_row("rir", j.value("rir", "-"));
        
        if (is_full) {
            print_flag("bogon", j.value("is_bogon", false));
            print_flag("datacenter", j.value("is_datacenter", false));
            print_flag("mobile", j.value("is_mobile", false));
            print_flag("tor", j.value("is_tor", false));
            print_flag("satellite", j.value("is_satellite", false));
            print_flag("proxy", j.value("is_proxy", false));
            print_flag("crawler", j.value("is_crawler", false));
            print_flag("vpn", j.value("is_vpn", false));
        }
        print_flag("abuser (IP)", is_ip_abuser);
        cout << endl;

        // --- COMPANY & NETWORK SECTION ---
        if (j.contains("company") && j["company"].is_object()) {
            cout << C_HEAD_COMP << "NETWORK" << C_RST << endl;
            cout << C_SEP << "-----------------" << C_RST << endl;
            auto comp = j["company"];
            print_row("name", comp.value("name", "-"));
            if (comp.contains("domain")) print_row("domain", comp.value("domain", "-"));
            if (comp.contains("type")) print_row("type", comp.value("type", "-"));
            if (comp.contains("network")) print_row("network", comp.value("network", "-"));
            if (comp.contains("abuser_score")) print_score_row("abuser_score", comp.value("abuser_score", "-"));
            cout << endl;
        }

        // --- ASN SECTION ---
        cout << C_HEAD_ASN << "ASN" << C_RST << endl;
        cout << C_SEP << "---" << C_RST << endl;
        if (j.contains("asn") && j["asn"].is_object()) {
            auto asn = j["asn"];
            string asn_num = "-";
            if (asn.contains("asn")) {
                if (asn["asn"].is_number()) asn_num = to_string(asn["asn"].get<int>());
                else asn_num = asn.value("asn", "-");
            }
            print_row("asn", asn_num);
            print_row("org", asn.value("org", "-"));
            if (asn.contains("route")) print_row("route", asn.value("route", "-"));
            if (asn.contains("type")) print_row("type", asn.value("type", "-"));
            if (asn.contains("abuser_score")) print_score_row("abuser_score", asn.value("abuser_score", "-"));
        } else {
            string asn_num = "-";
            if (j.contains("asn_num")) {
                if (j["asn_num"].is_number()) asn_num = to_string(j["asn_num"].get<int>());
                else asn_num = j.value("asn_num", "-");
            }
            print_row("asn", asn_num);
            print_row("org", j.value("asn_org", "-"));
        }
        cout << endl;

        // --- LOCATION SECTION ---
        cout << C_HEAD_LOC << "LOCATION" << C_RST << endl;
        cout << C_SEP << "--------" << C_RST << endl;
        if (j.contains("location") && j["location"].is_object()) {
            auto loc = j["location"];
            print_row("country", loc.value("country", "-"));
            
            if (is_full) {
                if (loc.contains("state")) print_row("state", loc.value("state", "-"));
                if (loc.contains("city")) print_row("city", loc.value("city", "-"));
                if (loc.contains("zip")) print_row("zip", loc.value("zip", "-"));
            }
            
            if (loc.contains("timezone")) print_row("timezone", loc.value("timezone", "-"));
            
            if (is_full) {
                string latlon = "- / -";
                if (loc.contains("latitude") && loc.contains("longitude") && loc["latitude"].is_number() && loc["longitude"].is_number()) {
                    latlon = format_double(loc["latitude"].get<double>()) + " / " + format_double(loc["longitude"].get<double>());
                }
                print_row("lat/lon", latlon);
                if (loc.contains("accuracy")) print_row("accuracy", loc.value("accuracy", "-"));
            }
        } else {
            print_row("country", j.value("cc", "-"));
            if (is_full) {
                string latlon = "- / -";
                if (j.contains("lat") && j.contains("lon") && j["lat"].is_number() && j["lon"].is_number()) {
                    latlon = format_double(j["lat"].get<double>()) + " / " + format_double(j["lon"].get<double>());
                }
                print_row("lat/lon", latlon);
            }
        }
        cout << endl;

        int requests_today = update_and_get_counter();
        cout << C_SEP << "API Quota: " << C_RST << C_VAL << requests_today << " / 1000" << C_RST << C_SEP << " requests today" << C_RST << "\n" << endl;

    } catch (json::parse_error& e) {
        cerr << "JSON Parse error: " << e.what() << endl;
        return 1;
    }
    return 0;
}
