function [z_out,tag,test_save, rho_mat, time_mat, max_time] = ADMM_DR_asy_ARock_Gurobi( f, g, rel_mat, rho, max_step, epsi_rel, epsi_abs, accuracy, empty_tag, rand_num )
  
    options = optimoptions('quadprog','Display','off');
    veh_num = size(g,2);
    if ~isempty(rel_mat)
        [c_size, p_size] = size(rel_mat);
        Np = size(f{1,1}.z_temp,1);
        z_out = zeros(p_size,Np);
        ceshi = zeros(p_size, Np);
        ADMM_tag = 1;
        tag = 0;
        test_save = [];
        rho_mat = [rho,0];
        time_mat = [];
        AA = eye((p_size+2*(c_size-p_size))*Np, (p_size+2*(c_size-p_size))*Np);
        BB = zeros((p_size+2*(c_size-p_size))*Np, p_size*Np);
        for i = 1:c_size
            if i <= p_size
                BB((i-1)*Np+1:(i-1)*Np+Np, (i-1)*Np+1:(i-1)*Np+Np) = eye(Np);
            else
                pd = find(rel_mat(i,:) == 1);
                BB(p_size*Np+(i-p_size-1)*2*Np+1:p_size*Np+(i-p_size-1)*2*Np+Np, (pd(1)-1)*Np+1:(pd(1)-1)*Np+Np) = eye(Np);
                BB(p_size*Np+(i-p_size-1)*2*Np+Np+1:p_size*Np+(i-p_size-1)*2*Np+2*Np, (pd(2)-1)*Np+1:(pd(2)-1)*Np+Np) = eye(Np);
            end
        end
        BB = -BB;

        %% asychronous ���ݽṹ
        A_set_save = [];
        thres_time = 1;
        thres_step = 2;
        ALL_set = 1:c_size;
        A_set = 1:c_size;
        C_set = [];
        newC_set = [];
        for i = A_set
            if i<=p_size
                f{1,i}.rece_mat = g{1,f{1,i}.rece_info(1,1)}.z_temp;
            else
                f{1,i}.rece_mat = [g{1,f{1,i}.rece_info(1,1)}.z_temp;g{1,f{1,i}.rece_info(1,2)}.z_temp];
            end
        end
        for i = 1:p_size             
            for j = 1:g{1,i}.N
                if ismember(g{1,i}.rece_info(1,j), A_set)
                    g{1,i}.rece_mat(:,j) = f{1,g{1,i}.rece_info(1,j)}.z_temp((g{1,i}.rece_info(2,j)-1)*Np+1:(g{1,i}.rece_info(2,j)-1)*Np+Np)+f{1,g{1,i}.rece_info(1,j)}.lambda((g{1,i}.rece_info(2,j)-1)*Np+1:(g{1,i}.rece_info(2,j)-1)*Np+Np)'/rho;                        
                end                  
            end                
        end  
        over_relx = 1.7;
        tau_inc =1;
        tau_dec = 1;
%         eta_inc = 1;
%         eta_dec = 1;
        mu = 1.2;
        cumu = 3;
        yita = 1;
%         iin = 0;
        eta_tag = 0;
        while true
             for i = 1:p_size
                g{1,i}.x = zeros(Np,1);
                for j = 1:g{1,i}.N
                    g{1,i}.x = g{1,i}.x+g{1,i}.rece_mat(:,j);
                end
                g{1,i}.z_retain = g{1,i}.z_temp;
                g{1,i}.z_temp = g{1,i}.x/g{1,i}.N;
             end
            %% ���ݴ��� 
            for i = A_set
                if i<=p_size
                    f{1,i}.rece_mat = over_relx*g{1,f{1,i}.rece_info(1,1)}.z_temp+(1-over_relx)*f{1,i}.z_temp;
                else
                    f{1,i}.rece_mat = [over_relx*g{1,f{1,i}.rece_info(1,1)}.z_temp+(1-over_relx)*f{1,i}.z_temp(1:Np);over_relx*g{1,f{1,i}.rece_info(1,2)}.z_temp+(1-over_relx)*f{1,i}.z_temp(Np+1:2*Np)];
                end
            end           
            %% ��һ�� ,,ll
            for i = 1:c_size
                if ismember(i, A_set)
                    A_set_save(ADMM_tag, i) = 1;
                else
                    A_set_save(ADMM_tag, i) = 0;
                end
            end
            for i = A_set
               % t1 = clock;
                f{1,i}.H = 2*(f{1,i}.H_o+0.5*rho*eye(f{1,i}.mat_size));
                f{1,i}.f = f{1,i}.f_o+f{1,i}.lambda'-rho*f{1,i}.rece_mat;
                if empty_tag == 0
                    t1 = clock;    
                    model = [];
                    model.Q = sparse(0.5*f{1,i}.H);
                    model.A = sparse(f{1,i}.A_o);
                    model.obj = f{1,i}.f';
                    model.rhs = f{1,i}.b_o';
                    model.lb = f{1,i}.lb_o';
                    model.ub = f{1,i}.ub_o';
                    model.sense = '<';
                    gurobi_write(model, 'qp.lp');
                    params.outputflag = 0;
                    
                    results = gurobi(model, params);
                    t2 = clock;
                    if results.status(1) == 'I'
                        t1 = clock;
                        model = [];
                        model.Q = sparse(0.5*f{1,i}.H);
                        model.A = sparse(A);
                        model.obj = f{1,i}.f';
                        model.rhs = f{1,i}.b_o';
                        model.sense = '<';
                        gurobi_write(model, 'qp.lp');
                        params.outputflag = 0;
                        
                        results = gurobi(model, params);
                        t2 = clock;
                    end
                    f{1,i}.x = results.x;
                    f{1,i}.z_retain = f{1,i}.z_temp;
                    f{1,i}.z_temp = Other_boundFun(f{1,i}.x, [f{1,i}.lb_o, f{1,i}.ub_o]); % ����õ�ֵ���������½緶Χ��
                else
                    model = [];
                    model.Q = sparse(0.5*f{1,i}.H);
                    model.A = sparse(A);
                    model.obj = f{1,i}.f';
                    model.rhs = f{1,i}.b_o';
                    model.sense = '<';
                    gurobi_write(model, 'qp.lp');
                    params.outputflag = 0;
                    t1 = clock;
                    results = gurobi(model, params);
                    t2 = clock;
                    f{1,i}.x = results.x; 
                    f{1,i}.z_retain = f{1,i}.z_temp;
                    f{1,i}.z_temp = f{1,i}.x;
                end
               % t2  =clock;
                time_mat(ADMM_tag, i) = etime(t2,t1);
                if time_mat(ADMM_tag, i)> thres_time
                    newC_set = [newC_set, [i; min(ceil(time_mat(ADMM_tag, i)/thres_time), thres_step)]];
                end
            end                    
            %% ������
            for i = A_set
                f{1,i}.lambda = f{1,i}.lambda+yita*(rho*(f{1,i}.z_temp- f{1,i}.rece_mat)');
            end
            for i = A_set
                f{1,i}.z_temp = f{1,i}.z_retain+yita*(f{1,i}.z_temp-f{1,i}.z_retain);
            end
               %% ���ݴ���
            C_set = [];
            for i = 1:size(newC_set, 2)
                if newC_set(2,i) >= 2
                    C_set = [C_set, newC_set(1,i)];
                end
                newC_set(2,i) = newC_set(2,i)-1;
            end
            if ~isempty(newC_set)
                newC_set(:,newC_set(2,:) == 0) = [];
            end
%            % scheme 1
%             BA = randperm(c_size);
%             A_set = BA(1:rand_num);
            % scheme 2
            BA = sortrows([1:c_size; time_mat(ADMM_tag, :)]', 2);
            BA = BA';
            A_set = BA(1, 1:rand_num);
            
            for i = 1:p_size             
                for j = 1:g{1,i}.N
                    if ismember(g{1,i}.rece_info(1,j), A_set)
                        g{1,i}.rece_mat(:,j) = f{1,g{1,i}.rece_info(1,j)}.z_temp((g{1,i}.rece_info(2,j)-1)*Np+1:(g{1,i}.rece_info(2,j)-1)*Np+Np)+f{1,g{1,i}.rece_info(1,j)}.lambda((g{1,i}.rece_info(2,j)-1)*Np+1:(g{1,i}.rece_info(2,j)-1)*Np+Np)'/rho;                        
                    end                  
                end                
            end
            %% �����ж�
            XX = zeros((p_size+2*(c_size-p_size))*Np, 1);
            XX_re = zeros((p_size+2*(c_size-p_size))*Np, 1);
            YY = zeros((p_size+2*(c_size-p_size))*Np, 1);
            for i = 1:c_size
                if i <= p_size
                    XX((i-1)*Np+1:(i-1)*Np+Np) = f{1,i}.z_temp;
                    XX_re((i-1)*Np+1:(i-1)*Np+Np) = f{1,i}.z_retain;
                    YY((i-1)*Np+1:(i-1)*Np+Np) = f{1,i}.lambda;
                else
                    XX(p_size*Np+(i-p_size-1)*2*Np+1:p_size*Np+(i-p_size-1)*2*Np+2*Np) = f{1,i}.z_temp;
                    XX_re(p_size*Np+(i-p_size-1)*2*Np+1:p_size*Np+(i-p_size-1)*2*Np+2*Np) = f{1,i}.z_retain;
                    YY(p_size*Np+(i-p_size-1)*2*Np+1:p_size*Np+(i-p_size-1)*2*Np+2*Np) = f{1,i}.lambda;
                end
            end
            ZZ = zeros(p_size*Np, 1);
            ZZ_re = zeros(p_size*Np, 1);
            for i =1:p_size
                ZZ((i-1)*Np+1:(i-1)*Np+Np) = g{1,i}.z_temp;
                ZZ_re((i-1)*Np+1:(i-1)*Np+Np) = g{1,i}.z_retain;
            end
            % pri_residual
            mat_pri = AA*XX+BB*ZZ;
            tag_pri = norm(mat_pri);
            % dual_residual
            mat_dual = rho*BB'*AA*(XX-XX_re);
            tag_dual = norm(mat_dual);
            
            %% ��ֹ�ж�
            epsi_pri = sqrt((p_size+2*(c_size-p_size))*Np)*epsi_abs+epsi_rel*max(norm(AA*XX), norm(BB*ZZ));
            epsi_dual = sqrt((p_size+2*(c_size-p_size))*Np)*epsi_abs+epsi_rel*norm(BB'*YY);
            test_save = [test_save;tag_pri,tag_dual, epsi_pri, epsi_dual, 0];
            if tag_pri <= epsi_pri && tag_dual <= epsi_dual
                for i = 1:p_size
                    z_out(i,:) = g{1,i}.z_temp;
                end
                tag = ADMM_tag;
                max_time = sum(max(time_mat, [], 2));
                for i = 1:p_size
                    ceshi(i,:) = g{1,i}.z_temp;
                end
                ERror = max(abs((accuracy - ceshi)/max(abs(accuracy)))*100); % �������
                test_save(end, end) = ERror;
    %             disp(['step=',num2str(ADMM_tag)])
                break;    
            elseif ADMM_tag>=max_step
                for i = 1:p_size
                    z_out(i,:) = g{1,i}.z_temp;
                end
                tag = ADMM_tag;
                break;
            else
                for i = 1:p_size
                    ceshi(i,:) = g{1,i}.z_temp;
                end
                ERror = max(abs((accuracy - ceshi)/max(abs(accuracy)))*100); % �������
                test_save(end, end) = ERror;
                if mod(ADMM_tag,2) == 0
                    disp('---------')
                    disp(['arrival set =', num2str(rand_num)]);
                    disp(['step=',num2str(ADMM_tag)]);
                    disp(['rho = ', num2str(rho)]);
                    disp(['yita = ', num2str(yita)]);
                    disp(['epsi_pri=',num2str(epsi_pri)]);
                    disp(['pri=',num2str(tag_pri)]);
                    disp(['epsi_dual=',num2str(epsi_dual)]);
                    disp(['dual=',num2str(tag_dual)]);
                    disp(['error(%) = ', num2str(ERror)]);
                    disp('---------')
                end
                %% ��yita����
%                 if ADMM_tag>2 && tag_dual - test_save(end-1, 2) > 0
%                     eta_tag = eta_tag+1;
%                 else  
%                     eta_tag = eta_tag-1;
%                 end
%                 
%                 if eta_tag >= cumu
%                     yita = max(yita/eta_dec, 0.1);
%                     eta_tag = 0;
%                 elseif eta_tag <= -cumu
%                     yita = min(1, yita*eta_inc);
%                     eta_tag = 0;
%                 end
                
                if tag_pri/epsi_pri>=mu*tag_dual/epsi_dual
%                 if 1>=mu*tag_dual/epsi_dual
                    rho_mat(ADMM_tag+1,:) = [rho,rho_mat(ADMM_tag,2)+1];
                elseif tag_dual/epsi_dual>=mu*tag_pri/epsi_pri
%                 elseif 1>=mu*tag_pri/epsi_pri
                    rho_mat(ADMM_tag+1,:) = [rho,rho_mat(ADMM_tag,2)-1];
                else
                    rho_mat(ADMM_tag+1,:) = [rho,rho_mat(ADMM_tag,2)];
                end
                if rho_mat(ADMM_tag+1,2)>=cumu
                    rho = min(rho*tau_inc,10000);
                    rho_mat(ADMM_tag+1,2) = 0;
                elseif rho_mat(ADMM_tag+1,2)<=-cumu
                    rho = rho/tau_dec;
                    rho_mat(ADMM_tag+1,2) = 0;
                end
                ADMM_tag = ADMM_tag+1;       
            end
        end
    else
        tag = [];
        test_save = [];
        rho_mat = [];
        c_size = size(f,2);
        Np = size(f{1,1}.z_temp, 1);
        z_out = zeros(c_size, Np);
        for i = 1:c_size
            f{1,i}.H = 2*f{1,i}.H_o;
            f{1,i}.f = f{1,i}.f_o;
            if sum(f{1,i}.H) ~= 0
                f{1,i}.x = quadprog(f{1,i}.H, f{1,i}.f, f{1,i}.A_o, f{1,i}.b_o, [], [], f{1,i}.lb_o, f{1,i}.ub_o,[],options);
    %             f{1,i}.x = quadprog(f{1,i}.H, f{1,i}.f, [], [], [], [], [], [],[],options);
                if isempty(f{1,i}.x) % ��ֹ���Բ���ʽԼ�������½�Լ���޽����������޽������ȥ�����½�Լ���������
                    f{1,i}.x = quadprog(f{1,i}.H, f{1,i}.f, f{1,i}.A_o, f{1,i}.b_o, [], [], [], [],[],options);
                end
                f{1,i}.z_temp = Math_bound(f{1,i}.x, f{1,i}.lb_o(1,1), f{1,i}.ub_o(1,1)); % ����õ�ֵ���������½緶Χ��
            else
                f{1,i}.z_temp = zeros(Np,1);
            end
            ceshi(i,:) = f{1,i}.z_temp;
        end
        for i = 1:c_size
            z_out(i,:) = f{1,i}.z_temp;
        end
        ERror = sum(accuracy - ceshi)/veh_num;
        disp(['error = ', num2str(ERror)]);
    end
end
