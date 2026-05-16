
						AREA datos, DATA
principiotablero		EQU 0x40007e00
IRQ_teclado   			EQU 7                 ; Índice de la IRQ (UART1)
IRQ_timer				EQU 4
VICIntEnable  			EQU 0xFFFFF010        
VICIntEnClr   			EQU 0xFFFFF014      
VICVectAddr0  			EQU 0xFFFFF100        
VICVectAddr   			EQU 0xFFFFF030        
RDAT          			EQU 0xE0010000        ; Registro de datos (UART1)
terminar      			DCD 0   
semilla					DCD 6748
mask 					EQU 0x1ff
tecla					DCB 0
						ALIGN
crono 					DCD 0
max 					DCD 8 
next 					DCD 0 ;instante siguiente movimiento
pos_jug1				DCD 0
pos_jug2				DCD 0
pos_fantasmas			DCD 0,0,0,0
vidas_j1        		DCD 20	
vidas_j2        		DCD 20
puntos_j1       		DCD 0
puntos_j2       		DCD 0
	
dir1x 					DCB 0 ;mov. horizontal personaje 1 (-1 izq,0 stop,1 derecha)
dir1y 					DCB 0 ;mov. vertical personaje 1 (-1 arriba,0 stop,1 abajo)
dir2x 					DCB 0 ;mov. horizontal personaje 2 (-1 izq,0 stop,1 derecha)
dir2y	 				DCB 0 ;mov. vertical personaje 2 (-1 arriba,0 stop,1 abajo)
T0_IR       	  		EQU 0xE0004000        ; Registro para bajar petición del timer


						AREA codigo,CODE
						EXPORT inicio			; forma de enlazar con el startup.s
						IMPORT srand			; para poder invocar SBR srand
						IMPORT rand	

										;inicio
	;------------------------------------------------------------------
	;Vic de los cojones

inicio
						ldr r0, =VICVectAddr0
						ldr r1, =RSI_teclado
						mov r2, #IRQ_teclado
						str r1, [r0, r2, lsl #2]
						ldr r1, =RSI_timer
						mov r2, #IRQ_timer
						str r1, [r0,r2, lsl #2]	
						
						; Habilitamos las interrupciones
						ldr r0, =VICIntEnable
						ldr r1, [r0]
						orr r1, r1, #1<<IRQ_teclado 
						orr r1, r1, #1<<IRQ_timer    
						str r1, [r0]    ; un solo str guarda ambos cambios
						
					; inicializamos la semilla
						ldr r0, =semilla
						ldr r1, [r0]
						push {r1}           
						bl srand           
						add sp, sp, #4

						; generamos el tablero
						LDR r0, =principiotablero
						EOR r1, r1, r1    
						MOV r2, #46         ; r2 = .

generar_tablero
						CMP r1, #512       
						BGE fin_puntos      ; Si r1 >= 512, salimos
						STRB r2, [r0, r1]   ; Escribimos el punto en la posición r1
						ADD r1, r1, #1      ; r1++
						B generar_tablero     

fin_puntos
						; ponemos los personajes encima
						bl gen_personajes
						bl generar_fantasmas
		
buc
						;bucle principal
						bl procesar_tecla
						;Gestionar el movimiento por tiempo (donde usamos crono, max y next)
						bl gestionar_juego
						; comprobamos muerte
						bl comprobar_muerte
						; Comprobar si el juego debe terminar
						ldr r0, =terminar
						ldr r1, [r0]
						cmp r1, #1
						beq fin 
						b buc
								
								
fin 					
						ldr r0, =puntos_j1
						ldr r0, [r0]
						ldr r1, =puntos_j2
						ldr r1, [r1]
						
						cmp r0, r1
						; Aquí podrías encender un LED o escribir en memoria
						; quién es el ganador.
						
						b fin ; Bucle infinito final



						; Inhabilitamos la interrupción de teclado en el VIC
						ldr r0, =VICIntEnClr
						mov r1, #1<<IRQ_teclado 
						mov r1, #1<<IRQ_timer
						str r1, [r0]	

	;--------------------------------------------
gen_personajes	
						push {r4, r10, lr}
						ldr r10, =mask
						ldr r0, =principiotablero
						; JUGADOR 1 
						sub sp, sp, #4
						bl rand
						pop{r3}
								; Sacamos el número calculado
						and r3, r3, r10     ; Aplicamos máscara 0x1ff
						mov r1, #64         ; 
						strb r1, [r0, r3]   ; Dibujamos en el tablero
						ldr r4, =pos_jug1
						str r3, [r4]        ; 
						; JUGADOR 2
						sub sp, sp, #4
						bl rand
						pop{r3}
						and r3, r3, r10
						mov r1, #38         
						strb r1, [r0, r3]   ; Dibujamos en el tablero
						ldr r4, =pos_jug2
						str r3, [r4]        ; guardamos la posición
						pop {r4, r10, pc}

	;---------------------------------------------------------------------------
generar_fantasmas  
						push { r0, r10, lr}
						ldr r0, =principiotablero
						ldr r10, =mask
						ldr r5, =pos_fantasmas

						mov r4, #0
buc_fantasmas			cmp r4, #4
						beq fin_gen
						sub sp, sp, #4
						bl rand
						pop {r3}
						and r3, r3, r10   ;mascara para delimitar
						ldrb r2, [r0, r3]	 ; en r2 tengo la posición actual
						cmp r2, #64
						beq buc_fantasmas
						cmp r2, #38
						beq buc_fantasmas
						mov r1, #42	
						str r3,[r5,r4,lsl#2] ; '*'
						strb r1, [r0, r3]
						add r4, r4, #1
						b 	buc_fantasmas
		
fin_gen					pop {r4, r10, pc}




;---------------------------------------------------------
act_pos_jug

						push {r0-r7, lr}    
						
						ldr r0, =principiotablero
						ldr r10, =mask             ; r10 = 0x1FF
						mov r3, #32                 ; nos comemos el puntito

						; --- PROCESAR JUGADOR 1 ---
						ldr r4, =pos_jug1
						ldr r1, [r4]                ; r1 = posición actual
						strb r3, [r0, r1]           ; Borramos el '@' de la posición antigua

						; 1. Separamos FILA y COLUMNA de J1
						bic r2, r1, #0x1F           ; r2 = Solo la base de la FILA (bits altos)
						and r1, r1, #0x1F           ; r1 = Solo la COLUMNA (bits 0-4)

						; 2. Calculamos movimiento según tus comparaciones
						ldr r6, =dir1x
						ldrsb r4, [r6]              ; r4 = dir1x
						ldr r6, =dir1y
						ldrsb r5, [r6]              ; r5 = dir1y

						; Aplicamos movimiento horizontal sobre la COLUMNA (r1)
						cmp r4, #1
						addeq r1, r1, #1            ; Derecha
						cmp r4, #-1
						subeq r1, r1, #1            ; Izquierda
						and r1, r1, #0x1F           ; TÚNEL HORIZONTAL ESTRICTO (0-31)

						; Aplicamos movimiento vertical sobre la FILA (r2)
						cmp r5, #1
						addeq r2, r2, #32           ; Abajo
						cmp r5, #-1
						subeq r2, r2, #32           ; Arriba

						; 3. Recomponemos posición J1
						orr r1, r1, r2              ; Unimos nueva fila y nueva columna
						and r1, r1, r10             ; Máscara global para túnel vertical total
						ldr r4, =pos_jug1
						str r1, [r4]                ; Guardamos J1


						; --- PROCESAR JUGADOR 2 ---
						ldr r5, =pos_jug2
						ldr r2, [r5]                ; r2 = posición actual
						strb r3, [r0, r2]           ; Borramos el '&' antiguo

						; 1. Separamos FILA y COLUMNA de J2
						bic r7, r2, #0x1F           ; r7 = Solo la FILA
						and r2, r2, #0x1F           ; r2 = Solo la COLUMNA

						; 2. Calculamos movimiento J2
						ldr r6, =dir2x
						ldrsb r4, [r6]              ; r4 = dir2x
						ldr r6, =dir2y
						ldrsb r5, [r6]              ; r5 = dir2y

						; Movimiento horizontal sobre COLUMNA (r2)
						cmp r4, #1
						addeq r2, r2, #1            ; Derecha
						cmp r4, #-1
						subeq r2, r2, #1            ; Izquierda
						and r2, r2, #0x1F           ; TÚNEL HORIZONTAL ESTRICTO

						; Movimiento vertical sobre FILA (r7)
						cmp r5, #1
						addeq r7, r7, #32           ; Abajo
						cmp r5, #-1
						subeq r7, r7, #32           ; Arriba

						; 3. Recomponemos posición J2
						orr r2, r2, r7
						and r2, r2, r10             ; Máscara global
						ldr r5, =pos_jug2
						str r2, [r5]                ; Guardamos J2


						; --- DIBUJAR NUEVAS POSICIONES ---
						; Dibujar J1 (@)
						mov r7, #64
						ldr r4, =pos_jug1
						ldr r1, [r4]
						strb r7, [r0, r1]

						; Dibujar J2 (&)
						mov r7, #38                
						ldr r5, =pos_jug2
						ldr r2, [r5]
						strb r7, [r0, r2]

						pop {r0-r7, pc}         

													
								
;------------------------------------------------------------------------------							
procesar_tecla
						push {r0-r3, lr}
						ldr r1, =tecla
						ldrb r0, [r1]
						
						cmp r0, #0
						beq fin_sub
						mov r2, #0
						strb r2, [r1]

						; --- Controles J1 ---
						cmp r0, #87 ; 'W'
						moveq r2, #0
						moveq r3, #-1
						beq actualizar_j1
						cmp r0, #83 ; 'S'
						moveq r2, #0
						moveq r3, #1
						beq actualizar_j1
						cmp r0, #65 ; 'A'
						moveq r2, #-1
						moveq r3, #0
						beq actualizar_j1
						cmp r0, #68 ; 'D'
						moveq r2, #1
						moveq r3, #0
						beq actualizar_j1

						; --- Controles J2 ---
						cmp r0, #73 ; 'I'
						moveq r2, #0
						moveq r3, #-1
						beq actualizar_j2
						cmp r0, #75 ; 'K'
						moveq r2, #0
						moveq r3, #1
						beq actualizar_j2
						cmp r0, #74 ; 'J'
						moveq r2, #-1
						moveq r3, #0
						beq actualizar_j2
						cmp r0, #76 ; 'L'
						moveq r2, #1
						moveq r3, #0
						beq actualizar_j2
						
						; --- Gestión de velocidad ---
						ldr r1, =max
						ldr r2, [r1]
						cmp r0, #43          ; '+'
						beq aumentar_mas
						
						cmp r0, #45          ; '-'
						beq disminuir_mas    ; <-- CAMBIO 1: Salto directo para evitar líos
						
						b comprobar          ; <-- CAMBIO 2: Si no es + ni -, saltamos a comprobar Q

disminuir_mas                                ; <-- CAMBIO 3: Etiqueta propia para claridad
						cmp r2, #128
						lsllt r2, r2, #1
						str r2, [r1]
						b fin_sub            ; <-- IMPORTANTE: Salir al terminar

comprobar
						cmp r0, #81          ; 'Q'
						beq salir_juego
						b fin_sub

actualizar_j1
						ldr r0, =dir1x
						strb r2, [r0]
						ldr r0, =dir1y
						strb r3, [r0]
						b fin_sub

actualizar_j2
						ldr r0, =dir2x
						strb r2, [r0]
						ldr r0, =dir2y
						strb r3, [r0]
						b fin_sub

salir_juego
						ldr r0, =terminar
						mov r1, #1
						str r1, [r0]
						b fin_sub            ; <-- Seguridad

aumentar_mas
						cmp r2, #1
						lsrgt r2, r2, #1
						str r2, [r1]
						b fin_sub

fin_sub
						pop {r0-r3, pc}
;--------------------------------------------------
act_pos_fant			
						push {r0-r5, r10,lr}						;r5 --> direccion de principio tablero
						ldr r4, =pos_fantasmas	
						ldr r5, =principiotablero
						ldr r10,=mask
						eor r1,r1,r1						;r4 --> direccion del vector de las posiciones de los fantasmas (v)
buc_mov_fantasmas			        
						cmp r1,#4						;r2 --> '.' y cuando se mueve '*'
						ldr r0,[r4,r1,lsl#2]
						push {r1}				;r0 --> v[i]
						sub sp,sp,#4
						bl rand
						pop {r3}
						pop {r1}
						beq fin_mov_fantasmas					;r3 --> numero aleatorio
						mov r2,#46
						lsr r3,r3,#6							;r1 --> indicador del bucle
						and r3,r3,#0x03
						cmp r3,#0
						beq mov_izq
						cmp r3,#1
						beq mov_arriba
						cmp r3,#2
						beq mov_dcha
						cmp r3,#3
						beq mov_abajo

						
												
mov_izq					
						strb r2,[r0,r5]
						sub r0,r0,#1
						and r0,r0,r10
						str r0,[r4,r1,lsl#2]
						mov r2,#42
						strb r2,[r0,r5]	
						b siguiente_ciclo

mov_dcha				
						strb r2,[r0,r5]
						add r0,r0,#1
						and r0,r0,r10
						str r0,[r4,r1,lsl#2]
						mov r2,#42
						strb r2,[r0,r5]	
						b siguiente_ciclo
mov_abajo				
						strb r2,[r0,r5]
						add r0,r0,#32
						and r0,r0,r10
						str r0,[r4,r1,lsl#2]
						mov r2,#42
						strb r2,[r0,r5]	
						b siguiente_ciclo
mov_arriba					
						strb r2,[r0,r5]
						sub r0,r0,#32
						and r0,r0,r10
						str r0,[r4,r1,lsl#2]
						mov r2,#42
						strb r2,[r0,r5]	
						b siguiente_ciclo
						
siguiente_ciclo
						add r1,r1,#1
						b buc_mov_fantasmas
						
fin_mov_fantasmas		
						pop {r0-r5, r10,pc}
						
												
;--------------------------------------------------																			
gestionar_juego
						push {r0-r3, lr}
						ldr r0, =crono
						ldr r1, [r0]
						ldr r2, =next
						ldr r3, [r2]
						
						cmp r1, r3          ; ¿Ha llegado la hora?
						blt fin_gestionar   ; Si no, nos vamos
						bl act_pos_jug
						bl act_pos_fant
						; calculamos next
						ldr r0, =max
						ldr r0, [r0]      
						add r3, r1, r0      ; next = crono + max
						ldr r2, =next
						str r3, [r2]

fin_gestionar
						pop {r0-r3, pc}								
								
								
comprobar_muerte
						push {r0-r7, lr}
						ldr r0, =pos_jug1
						ldr r0, [r0]            ; r0 = pos J1
						ldr r1, =pos_jug2
						ldr r1, [r1]            ; r1 = pos J2
						ldr r2, =pos_fantasmas
						mov r3, #0              ; Índice del fantasma (0 a 3)

bucle_choque
						cmp r3, #4
						beq fin_choque          ; Si hemos revisado los 4 fantasmas, salir
						
						ldr r4, [r2, r3, lsl #2] ; r4 = posición del fantasma actual
						
						; comprobamos el jugador1
						cmp r0, r4              
						beq quitar_vida_j1
						
						; comprobamos el jugador2
						cmp r1, r4
						beq quitar_vida_j2
						
						add r3, r3, #1
						b bucle_choque

quitar_vida_j1
						ldr r5, =vidas_j1
						ldr r6, [r5]
						sub r6, r6, #1
						str r6, [r5]
						cmp r6, #0
						beq fin_partida         ; Si J1 llega a 0 vidas, fin
						add r3, r3, #1          ; Siguiente fantasma
						b bucle_choque

quitar_vida_j2
						ldr r5, =vidas_j2
						ldr r6, [r5]
						sub r6, r6, #1
						str r6, [r5]
						cmp r6, #0
						beq fin_partida         ; Si J2 llega a 0 vidas, fin
						add r3, r3, #1
						b bucle_choque

fin_partida
						ldr r0, =terminar
						mov r1, #1
						str r1, [r0]
	
fin_choque
						pop {r0-r7, pc}								
																		
								
								
								
								
								
								
								
								
								
								
								
								
								
								

RSI_teclado
;------------------------------------------------------------------       
						sub lr, lr, #4 
						push {lr}	
						; Guardar spsr en pila 
						mrs r14, spsr
						push {r14}	
						push {r0-r2}
						 ;Activar IRQ
						mrs r0, cpsr
						bic r0, r0, #2_10000000
						msr cpsr_c, r0 
						
						ldr r1, =RDAT ; r1 = @dato
						ldrb r0, [r1] ; r0 = codigo ASCII tecla
						; Solo convertimos a mayúsculas si es una letra minúscula (entre 'a' y 'z')
						cmp r0, #97          ; r0<a?
						blt guardar_tecla
						cmp r0, #122         ; r0 > z?
						bgt guardar_tecla
						bic r0, r0,#2_100000    ; Solo aquí convertimos a MAYÚSCULAS

guardar_tecla
						ldr r1, =tecla
						strb r0, [r1]
							; Desactivar IRQ
						mrs r0, cpsr
						orr r0, r0, #2_10000000 ; Poner a uno el bit 7
						msr cpsr_c, r0          ; Campo de control (_c)
							
							; Restaurar registros guardados en pila
						pop {r0-r2}
						pop {r14}
						msr spsr_fsxc, r14
				
						ldr r14, =VICVectAddr 									
						str r14, [r14] 											; Retorno con actualización de cpsr
						pop {pc}^
						  ;==============================================================================================
RSI_timer
			;------------------------------------------------------------------         
											 ; Corregir (por el segmentado) y apilar @ret          
						sub lr, lr, #4 
						push {lr}
						
						; Guardar spsr en pila (usamos lr porque ya lo hemos guardado)
						mrs r14, spsr
						push {r14}
						
						; Guardar registros usados en pila
						push {r0-r2}
						
						; Activar IRQ
						mrs r0, cpsr
						bic r0, r0, #2_10000000 ; Poner a cero el bit 7
						msr cpsr_c, r0          ; Campo de control (_c)
						
						; Bajar petición del timer
						ldr r1, =T0_IR
						mov r0, #1
						str r0, [r1]
						
						; Avanzar el timer
						ldr r1, =crono
						ldr r0, [r1]
						add r0, r0, #1
						str r0, [r1]
						
						; Desactivar IRQ
						mrs r0, cpsr
						orr r0, r0, #2_10000000 ; Poner a uno el bit 7
						msr cpsr_c, r0          ; Campo de control (_c)
						
						; Restaurar registros guardados en pila
						pop {r0-r2}
						
						; Restaurar spsr
						pop {r14}
						msr spsr_fsxc, r14; Todos los campos (_fsxc): flags [31:24], status [23:16], extension [15:8] y control [7:0]
						
						; End Of Interrupt (usando r14 que es el único libre)
						ldr r14, =VICVectAddr ; r14=@VICVectAddr
						str r14, [r14]        ; EOI --> escribir en VICVectAddr
						; Retorno con actualización de cpsr
						pop {pc}^
						END

