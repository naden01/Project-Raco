#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>

#define GAME_LIST "/data/ProjectRaco/game.txt"
#define RACO_SCRIPT "/data/ProjectRaco/Scripts/Raco.sh"

#define MAX_PATTERNS 256
#define MAX_PATTERN_LENGTH 256
#define BUFFER_SIZE 1024

typedef enum { EXEC_NONE, EXEC_GAME, EXEC_NORMAL } ExecType;

int main(void) {
    FILE *file = fopen(GAME_LIST, "r");
    if (!file) {
        fprintf(stderr, "Error: %s not found\n", GAME_LIST);
        return 1;
    }
    fclose(file);

    bool prev_screen_on = true;
    ExecType last_executed = EXEC_NONE;
    int delay_seconds = 5;

    while (1) {
        char patterns[MAX_PATTERNS][MAX_PATTERN_LENGTH];
        int num_patterns = 0;
        file = fopen(GAME_LIST, "r");
        if (file) {
            char line[BUFFER_SIZE];
            while (fgets(line, sizeof(line), file) && num_patterns < MAX_PATTERNS) {
                line[strcspn(line, "\n")] = '\0';
                if (line[0] == '\0') continue;
                if (strchr(line, ' ') != NULL) continue;
                strncpy(patterns[num_patterns], line, MAX_PATTERN_LENGTH - 1);
                patterns[num_patterns][MAX_PATTERN_LENGTH - 1] = '\0';
                num_patterns++;
            }
            fclose(file);
        }

        bool current_screen_on = true;
        FILE *screen_pipe = popen("dumpsys window | grep \"mScreenOn\" | grep false", "r");
        if (screen_pipe) {
            char screen_buffer[BUFFER_SIZE];
            if (fgets(screen_buffer, sizeof(screen_buffer), screen_pipe)) {
                current_screen_on = false;
            }
            pclose(screen_pipe);
        }

        if (current_screen_on != prev_screen_on) {
            if (current_screen_on) {
                printf("Screen turned on - setting delay to 5 seconds\n");
                delay_seconds = 5;
            } else {
                printf("Screen turned off - setting delay to 10 seconds for power conservation\n");
                delay_seconds = 10;
            }
            prev_screen_on = current_screen_on;
        }

        char matched_package[BUFFER_SIZE] = "";
        
        if (current_screen_on) {
            FILE *pipe_fp = popen("dumpsys window | grep 'mFocusedApp' | sed 's/.*ActivityRecord{[^ ]* [^ ]* \\([^ ]*\\/[^ ]*\\).*/\\1/'", "r");
            if (pipe_fp) {
                char buffer[BUFFER_SIZE];
                if (fgets(buffer, sizeof(buffer), pipe_fp)) {
                    buffer[strcspn(buffer, "\n")] = '\0';
                    
                    for (int i = 0; i < num_patterns; i++) {
                        if (strstr(buffer, patterns[i]) != NULL) {
                            strncpy(matched_package, patterns[i], sizeof(matched_package) - 1);
                            matched_package[sizeof(matched_package) - 1] = '\0';
                            break;
                        }
                    }
                }
                pclose(pipe_fp);
            }
        }

        if (current_screen_on && strlen(matched_package) > 0) {
            if (last_executed != EXEC_GAME) {
                printf("Game package detected: %s\n", matched_package);
                char command[BUFFER_SIZE];
                snprintf(command, sizeof(command), "sh %s 1", RACO_SCRIPT);
                system(command);
                last_executed = EXEC_GAME;
            }
        } else {
            if (last_executed != EXEC_NORMAL) {
                printf("Non-game package detected\n");
                char command[BUFFER_SIZE];
                snprintf(command, sizeof(command), "sh %s 2", RACO_SCRIPT);
                system(command);
                last_executed = EXEC_NORMAL;
            }
        }
        
        sleep(delay_seconds);
    }

    return 0;
}