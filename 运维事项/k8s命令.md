# k8s命令

> 来源: Trilium Notes 导出 | 路径: root/k8s命令


k8s命令




## k8s命令


1.批量删除状态为Exited的pod

`kubectl get pods --all-namespaces -o wide | grep Evicted | awk '{print "kubectl delete pod " $2 " -n " $1}' | sh`
2.批量把命名空间副本降为0

`kubectl -n yhb-server get deployment -o custom-columns=POD_NAME:.metadata.name --no-headers | xargs -I {} kubectl -n yhb-server scale deployment {} --replicas=0`
3.批量把命名空间副本调整为1

```
`kubectl -n bike-server-gaw get deployment -o custom-columns=POD_NAME:.metadata.name --no-headers | xargs -I {} kubectl -n bike-server-gaw scale deployment {} --replicas=1`
```

